#!/bin/bash
#
# KeyPulse Release Build Script
#
# This script builds KeyPulse for App Store distribution and TestFlight upload.
# It handles archiving, signing with hardened runtime, and preparing for upload.
#
# Prerequisites:
#   - macOS 13+ with Xcode 15+
#   - Apple Developer account with App Store Connect access
#   - Valid provisioning profile for com.keypulse.app
#   - Team ID configured in ExportOptions.plist
#
# Usage:
#   ./scripts/build-release.sh [version] [build_number]
#
# Example:
#   ./scripts/build-release.sh 1.0.0 10
#

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_DIR="${PROJECT_ROOT}/KeyPulse"

# Version and build number
VERSION="${1:-0.1.0}"
BUILD_NUMBER="${2:-1}"

# Build configuration
BUNDLE_ID="com.keypulse.app"
SCHEME="KeyPulse"
CONFIGURATION="Release"

# Output directories
BUILD_DIR="${PROJECT_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/KeyPulse-${VERSION}-${BUILD_NUMBER}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/KeyPulse-${VERSION}-${BUILD_NUMBER}"
EXPORT_OPTIONS_PLIST="${PROJECT_DIR}/ExportOptions.plist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
	echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo "KeyPulse Release Build Script"
echo "=========================================="
echo "Version:      ${VERSION}"
echo "Build Number: ${BUILD_NUMBER}"
echo "Bundle ID:    ${BUNDLE_ID}"
echo "=========================================="
echo ""

# Verify prerequisites
log_info "Verifying prerequisites..."

# Check for Xcode
if ! command -v xcodebuild &>/dev/null; then
	log_error "xcodebuild not found. Please install Xcode."
	exit 1
fi

# Check for Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
	log_error "Xcode Command Line Tools not found."
	log_info "Run: xcode-select --install"
	exit 1
fi

# Verify project structure
if [[ ! -f "${PROJECT_DIR}/Package.swift" ]]; then
	log_error "Package.swift not found at ${PROJECT_DIR}/Package.swift"
	exit 1
fi

# Verify entitlements file
if [[ ! -f "${PROJECT_DIR}/KeyPulse.entitlements" ]]; then
	log_error "Entitlements file not found at ${PROJECT_DIR}/KeyPulse.entitlements"
	exit 1
fi

# Verify export options
if [[ ! -f "${EXPORT_OPTIONS_PLIST}" ]]; then
	log_error "ExportOptions.plist not found at ${EXPORT_OPTIONS_PLIST}"
	exit 1
fi

log_info "Prerequisites verified."

# Clean build directory
log_info "Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Update version in Info.plist if needed
INFO_PLIST="${PROJECT_DIR}/Info.plist"
if [[ -f "${INFO_PLIST}" ]]; then
	log_info "Info.plist found at ${INFO_PLIST}"
	CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${INFO_PLIST}" 2>/dev/null || echo "unknown")
	CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${INFO_PLIST}" 2>/dev/null || echo "unknown")
	log_info "Current version: ${CURRENT_VERSION} (build ${CURRENT_BUILD})"

	if [[ "${CURRENT_VERSION}" != "${VERSION}" ]]; then
		log_warn "Version mismatch in Info.plist. Update manually if needed."
		log_info "Current: ${CURRENT_VERSION}, Requested: ${VERSION}"
	fi
fi

# Generate Xcode project from SwiftPM
log_info "Generating Xcode project..."
cd "${PROJECT_DIR}"
swift package generate-xcodeproj --skip-extra-files 2>/dev/null || {
	log_info "Using swift package for build (no xcodeproj needed)..."
}

# Clean and build archive
log_info "Creating archive..."
log_info "Archive path: ${ARCHIVE_PATH}"

# Build the archive using xcodebuild
# For SwiftPM projects, we use the scheme from the generated project or direct build
if xcodebuild -list -project "${PROJECT_DIR}/KeyPulse.xcodeproj" 2>/dev/null | grep -q "${SCHEME}"; then
	# Use xcodeproj if it exists
	xcodebuild archive \
		-project "${PROJECT_DIR}/KeyPulse.xcodeproj" \
		-scheme "${SCHEME}" \
		-configuration "${CONFIGURATION}" \
		-archivePath "${ARCHIVE_PATH}" \
		-destination "generic/platform=macOS" \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM="${TEAM_ID:-$(grep -A1 teamID "${EXPORT_OPTIONS_PLIST}" | grep string | sed 's/.*<string>//' | sed 's/<\/string>.*//' 2>/dev/null || echo "")}" \
		ENABLE_HARDENED_RUNTIME=YES \
		CODE_SIGN_ENTITLEMENTS="${PROJECT_DIR}/KeyPulse.entitlements" |
		tee "${BUILD_DIR}/archive.log"
else
	# SwiftPM direct build - create archive manually
	log_info "Using Swift Package Manager build..."

	# First, build for release
	swift build -c release 2>&1 | tee "${BUILD_DIR}/build.log"

	# Find the built executable
	RELEASE_BUILD_DIR="${PROJECT_DIR}/.build/release"
	if [[ ! -d "${RELEASE_BUILD_DIR}" ]]; then
		log_error "Release build directory not found at ${RELEASE_BUILD_DIR}"
		exit 1
	fi

	log_warn "SwiftPM direct build creates unsigned binary."
	log_warn "For App Store distribution, use 'swift package generate-xcodeproj' or Xcode."

	# Create a minimal archive structure for reference
	mkdir -p "${ARCHIVE_PATH}/Products/Applications"

	# Copy the binary
	cp "${RELEASE_BUILD_DIR}/KeyPulse" "${ARCHIVE_PATH}/Products/Applications/" 2>/dev/null || {
		log_error "Failed to copy built binary"
		exit 1
	}

	log_warn "Archive created without full signing. Use Xcode for proper App Store preparation."
fi

# Check if archive was created
if [[ ! -d "${ARCHIVE_PATH}" ]]; then
	log_error "Archive not created at ${ARCHIVE_PATH}"
	exit 1
fi

log_info "Archive created successfully: ${ARCHIVE_PATH}"

# Export the archive for App Store
log_info "Exporting archive for App Store..."
log_info "Export path: ${EXPORT_PATH}"

# Try to export if we have a proper Xcode archive
if [[ -f "${ARCHIVE_PATH}/Info.plist" ]]; then
	xcodebuild -exportArchive \
		-archivePath "${ARCHIVE_PATH}" \
		-exportPath "${EXPORT_PATH}" \
		-exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" |
		tee "${BUILD_DIR}/export.log" || {
		log_warn "Export may have failed - check export.log for details"
	}

	# Check for exported app
	if [[ -d "${EXPORT_PATH}/${SCHEME}.app" ]] || [[ -d "${EXPORT_PATH}/${BUNDLE_ID}.app" ]]; then
		log_info "Export successful!"

		# Find the exported .app
		EXPORTED_APP=$(find "${EXPORT_PATH}" -name "*.app" -type d | head -n1)
		if [[ -n "${EXPORTED_APP}" ]]; then
			log_info "Exported app: ${EXPORTED_APP}"

			# Verify code signature
			log_info "Verifying code signature..."
			codesign -dvv "${EXPORTED_APP}" 2>&1 | head -20

			# Show entitlements
			log_info "Entitlements:"
			codesign -d --entitlements - "${EXPORTED_APP}" 2>&1 || true
		fi
	else
		log_warn "No .app bundle found in export path"
		ls -la "${EXPORT_PATH}" || true
	fi
else
	log_warn "Archive Info.plist not found - skipping export step"
fi

# Show summary
echo ""
echo "=========================================="
echo "Build Summary"
echo "=========================================="
echo "Version:      ${VERSION}"
echo "Build Number: ${BUILD_NUMBER}"
echo "Bundle ID:    ${BUNDLE_ID}"
echo ""
echo "Artifacts:"
echo "  Archive:    ${ARCHIVE_PATH}"
if [[ -d "${EXPORT_PATH}" ]]; then
	echo "  Export:     ${EXPORT_PATH}"
fi
echo "  Logs:       ${BUILD_DIR}/"
echo ""

# Show files
log_info "Build artifacts:"
ls -lh "${BUILD_DIR}/" 2>/dev/null || true

echo ""
echo "=========================================="
echo "Next Steps for TestFlight"
echo "=========================================="
echo ""
echo "1. Verify archive in Xcode:"
echo "   open '${ARCHIVE_PATH}'"
echo ""
echo "2. Upload to App Store Connect (choose one method):"
echo ""
echo "   Method A - Using Transporter (command line):"
echo "   xcrun altool --upload-package '${EXPORT_PATH}/${SCHEME}.app' \\"
echo "       --type macos \\"
echo "       --asc-public-id 'YOUR_ASC_PUBLIC_ID' \\"
echo "       --apple-id 'YOUR_APP_APPLE_ID' \\"
echo "       --bundle-version '${BUILD_NUMBER}' \\"
echo "       --bundle-short-version-string '${VERSION}'"
echo ""
echo "   Method B - Using Xcode Organizer:"
echo "   open -a Xcode"
echo "   Window -> Organizer -> Archives -> Select Archive -> Distribute App"
echo ""
echo "   Method C - Using altool (legacy but reliable):"
echo "   xcrun altool --upload-app -f '${ARCHIVE_PATH}' -t macos \\"
echo "       -u 'your@email.com' -p '@keychain:AC_PASSWORD'"
echo ""
echo "3. Go to App Store Connect:"
echo "   https://appstoreconnect.apple.com"
echo ""
echo "4. Navigate to your app -> TestFlight tab"
echo ""
echo "5. Add testers to Internal Testing group:"
echo "   - App Store Connect Users -> Internal Testing -> Add Testers"
echo ""
echo "6. Testers will receive email invitation with TestFlight link"
echo ""
echo "=========================================="

log_info "Build complete!"

# Optional: Check for required entitlements
if command -v codesign &>/dev/null; then
	echo ""
	log_info "To verify hardened runtime after manual signing:"

	if [[ -d "${EXPORT_PATH}/${SCHEME}.app" ]]; then
		codesign -dv --verbose=4 "${EXPORT_PATH}/${SCHEME}.app" 2>&1 | grep -E "(Identifier|Authority|Hardened)" || true
	fi
fi

exit 0
