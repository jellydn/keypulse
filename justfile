# KeyPulse — Swift macOS app

# List available recipes
[private]
default:
    @just --list

# Build the project
build:
    cd KeyPulse && swift build

# Run tests
test:
    cd KeyPulse && swift test

# Build release binary
release:
    cd KeyPulse && swift build -c release

# Clean build artifacts
clean:
    cd KeyPulse && swift package clean
    rm -rf KeyPulse/.build

# Run the app (requires accessibility permissions)
run:
    cd KeyPulse && swift run

# Format Swift code with swift-format (if installed)
fmt:
    cd KeyPulse && swift-format format --in-place --recursive Sources/

# Lint Swift code with swift-format (if installed)
lint:
    cd KeyPulse && swift-format lint --recursive Sources/

# Generate Xcode project for GUI development
xcode:
    cd KeyPulse && swift package generate-xcodeproj 2>/dev/null || echo "Open Package.swift directly in Xcode"

# Install debug build to local bin
debug-install: build
    mkdir -p ~/.local/bin
    cp KeyPulse/.build/debug/KeyPulse ~/.local/bin/

# Show package dependencies
resolve:
    cd KeyPulse && swift package resolve

deps:
    cd KeyPulse && swift package show-dependencies

# Build app bundle for distribution
bundle:
    cd KeyPulse && swift build -c release
    mkdir -p dist/KeyPulse.app/Contents/MacOS
    mkdir -p dist/KeyPulse.app/Contents/Resources
    cp KeyPulse/.build/release/KeyPulse dist/KeyPulse.app/Contents/MacOS/
    cp KeyPulse/Info.plist dist/KeyPulse.app/Contents/
    cp KeyPulse/KeyPulse.entitlements dist/KeyPulse.app/Contents/
    cp -r KeyPulse/Sources/KeyPulse/Resources/* dist/KeyPulse.app/Contents/Resources/ 2>/dev/null || true
    echo "Created dist/KeyPulse.app"

# Clean dist folder
distclean:
    rm -rf dist/
