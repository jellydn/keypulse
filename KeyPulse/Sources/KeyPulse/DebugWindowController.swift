import AppKit
import Combine
import SwiftUI

/// Manages the Debug Window for live diagnostics and testing.
/// Provides a floating window showing keystroke stats, latency metrics,
/// and controls for testing sound profiles.
final class DebugWindowController: NSObject, NSWindowDelegate {
    /// The controller being monitored.
    private weak var controller: KeyPulseController?

    /// The debug window instance.
    private var window: NSWindow?

    /// The SwiftUI hosting controller.
    private var hostingController: NSHostingController<DebugView>?

    /// Cancellable for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Window frame autosave name for persistence.
    private let windowFrameName = "KeyPulseDebugWindow"

    /// Whether the window is currently visible.
    var isWindowVisible: Bool {
        return window?.isVisible ?? false
    }

    /// Creates a new debug window controller.
    /// - Parameter controller: The KeyPulseController to monitor and control.
    init(controller: KeyPulseController) {
        self.controller = controller
        super.init()
        setupWindow()
        setupSubscriptions()
    }

    deinit {
        window?.delegate = nil
    }

    // MARK: - Window Management

    /// Sets up the debug window.
    private func setupWindow() {
        // Create the SwiftUI view
        let debugView = DebugView(
            diagnostics: controller?.diagnosticsData ?? DiagnosticsData(),
            onProfileChanged: { [weak self] profile in
                guard let controller = self?.controller else { return }
                do {
                    try controller.setProfile(profile)
                } catch {
                    controller.onError?(error)
                }
            },
            onTestSound: { [weak self] in
                self?.controller?.testPlay()
            },
            onTestAllProfiles: { [weak self] in
                self?.controller?.testAllProfiles()
            },
            onResetStats: { [weak self] in
                self?.controller?.resetStats()
            },
            onCopyDiagnostics: { [weak self] in
                self?.copyDiagnosticsToClipboard()
            }
        )

        // Create hosting controller
        hostingController = NSHostingController(rootView: debugView)
        guard let hostingController = hostingController else { return }

        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 360, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // Configure window
        window.title = "KeyPulse Debug"
        window.level = .floating
        window.contentViewController = hostingController
        window.delegate = self
        window.setFrameAutosaveName(windowFrameName)

        // Don't show automatically
        window.isReleasedWhenClosed = false

        self.window = window
    }

    /// Sets up Combine subscriptions for real-time updates.
    private func setupSubscriptions() {
        guard let controller = controller else { return }

        // Subscribe to diagnostics data changes, throttled to 10 Hz max
        controller.$diagnosticsData
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] diagnostics in
                self?.updateView(with: diagnostics)
            }
            .store(in: &cancellables)
    }

    /// Updates the SwiftUI view with new diagnostics data.
    private func updateView(with diagnostics: DiagnosticsData) {
        guard let hostingController = hostingController else { return }

        // Update the view by creating a new root view with updated data
        let debugView = DebugView(
            diagnostics: diagnostics,
            onProfileChanged: { [weak self] profile in
                guard let controller = self?.controller else { return }
                do {
                    try controller.setProfile(profile)
                } catch {
                    controller.onError?(error)
                }
            },
            onTestSound: { [weak self] in
                self?.controller?.testPlay()
            },
            onTestAllProfiles: { [weak self] in
                self?.controller?.testAllProfiles()
            },
            onResetStats: { [weak self] in
                self?.controller?.resetStats()
            },
            onCopyDiagnostics: { [weak self] in
                self?.copyDiagnosticsToClipboard()
            }
        )

        hostingController.rootView = debugView
    }

    // MARK: - Public Methods

    /// Shows the debug window.
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hides the debug window.
    func hideWindow() {
        window?.orderOut(nil)
    }

    /// Toggles the debug window visibility.
    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    /// Copies current diagnostics to the clipboard.
    private func copyDiagnosticsToClipboard() {
        guard let diagnostics = controller?.diagnostics() else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics.formattedDiagnostics(), forType: .string)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of close to preserve state
        hideWindow()
        return false
    }
}

// MARK: - SwiftUI Views

/// SwiftUI view for the debug window content.
struct DebugView: View {
    /// Current diagnostics data.
    let diagnostics: DiagnosticsData

    /// Callbacks for user actions.
    let onProfileChanged: (SoundProfile) -> Void
    let onTestSound: () -> Void
    let onTestAllProfiles: () -> Void
    let onResetStats: () -> Void
    let onCopyDiagnostics: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                headerSection

                Divider()

                // Keystroke stats
                keystrokeSection

                Divider()

                // Profile and sample
                profileSection

                Divider()

                // Latency metrics
                latencySection

                Divider()

                // Modifier flags
                modifiersSection

                Divider()

                // Settings
                settingsSection

                Divider()

                // Actions
                actionsSection
            }
            .padding()
        }
        .frame(minWidth: 340, maxWidth: 400, minHeight: 400, maxHeight: 600)
    }

    // MARK: - View Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("KeyPulse Debug")
                .font(.title2)
                .fontWeight(.bold)

            Text("Live diagnostics and testing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var keystrokeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keystrokes")
                .font(.headline)

            HStack {
                Text("Total:")
                    .fontWeight(.medium)
                Spacer()
                Text("\(diagnostics.totalKeystrokes)")
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Last Key:")
                    .fontWeight(.medium)
                Spacer()
                Text(diagnostics.lastKeyDisplayName)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Code:")
                    .fontWeight(.medium)
                Spacer()
                Text("\(diagnostics.lastKeyCode) (0x\(String(format: "%02X", diagnostics.lastKeyCode)))")
                    .font(.system(.caption, design: .monospaced))
            }

            if diagnostics.isLastKeyModifier {
                Text("Type: Modifier (flagsChanged)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile & Sample")
                .font(.headline)

            // Profile switcher
            Picker("Profile:", selection: Binding(
                get: { diagnostics.activeProfile },
                set: { onProfileChanged($0) }
            )) {
                Text("Linear").tag(SoundProfile.linear)
                Text("Tactile").tag(SoundProfile.tactile)
                Text("Clicky").tag(SoundProfile.clicky)
            }
            .pickerStyle(SegmentedPickerStyle())

            HStack {
                Text("Active:")
                    .fontWeight(.medium)
                Spacer()
                Text(diagnostics.activeProfile.displayName)
            }

            HStack {
                Text("Last Sample:")
                    .fontWeight(.medium)
                Spacer()
                Text("\(diagnostics.lastSampleIndex): \(diagnostics.lastSampleFilename)")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
            }
        }
    }

    private var latencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latency (ms)")
                .font(.headline)

            HStack {
                Text("Average:")
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.3f", diagnostics.latencyAverageMs))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(latencyColor)
            }

            HStack {
                Text("Min:")
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.3f", diagnostics.latencyMinMs))
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Max:")
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.3f", diagnostics.latencyMaxMs))
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Samples:")
                    .fontWeight(.medium)
                Spacer()
                Text("\(diagnostics.latencySampleCount)")
                    .font(.system(.body, design: .monospaced))
            }

            // Status indicator
            HStack {
                Text("Target: < 20ms")
                    .font(.caption)
                Spacer()
                if diagnostics.latencyAverageMs < 20 {
                    Text("✅ PASS")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("❌ FAIL")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var modifiersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modifier Flags")
                .font(.headline)

            HStack(spacing: 12) {
                ModifierIndicator(label: "⇧", isActive: diagnostics.isShiftPressed)
                ModifierIndicator(label: "⌘", isActive: diagnostics.isCommandPressed)
                ModifierIndicator(label: "⌥", isActive: diagnostics.isOptionPressed)
                ModifierIndicator(label: "⌃", isActive: diagnostics.isControlPressed)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)

            HStack {
                Text("Volume:")
                    .fontWeight(.medium)
                Spacer()
                Text("\(diagnostics.volumePercent)%")
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Muted:")
                    .fontWeight(.medium)
                Spacer()
                Text(diagnostics.isMuted ? "Yes" : "No")
                    .foregroundColor(diagnostics.isMuted ? .red : .green)
            }

            HStack {
                Text("Pitch Var:")
                    .fontWeight(.medium)
                Spacer()
                Text(diagnostics.isPitchVariationEnabled ? "On" : "Off")
                    .foregroundColor(diagnostics.isPitchVariationEnabled ? .green : .secondary)
            }

            HStack {
                Text("Enabled:")
                    .fontWeight(.medium)
                Spacer()
                Text(diagnostics.isEnabled ? "Yes" : "No")
                    .foregroundColor(diagnostics.isEnabled ? .green : .red)
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Test Sound") {
                    onTestSound()
                }
                .disabled(diagnostics.isMuted)

                Button("Test All") {
                    onTestAllProfiles()
                }
                .disabled(diagnostics.isMuted)
            }

            HStack(spacing: 8) {
                Button("Reset Stats") {
                    onResetStats()
                }

                Button("Copy Diags") {
                    onCopyDiagnostics()
                }
            }
        }
    }

    /// Color for latency display based on performance.
    private var latencyColor: Color {
        if diagnostics.latencyAverageMs < 10 {
            return .green
        } else if diagnostics.latencyAverageMs < 20 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Indicator view for modifier keys.
struct ModifierIndicator: View {
    let label: String
    let isActive: Bool

    var body: some View {
        Text(label)
            .font(.title3)
            .fontWeight(.bold)
            .frame(width: 32, height: 32)
            .background(isActive ? Color.blue : Color.gray.opacity(0.3))
            .foregroundColor(isActive ? .white : .secondary)
            .cornerRadius(6)
    }
}
