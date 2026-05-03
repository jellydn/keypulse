import AppKit
import SwiftUI

// MARK: - PreferencesWindowController

/// Manages the Preferences window for KeyPulse settings.
/// Provides a SwiftUI-based window with three tabs: General, Sounds, and Advanced.
/// All controls bind to SettingsStore as the single source of truth.
///
/// Architecture: passes SettingsStore (ObservableObject) and KeyPulseController
/// to the SwiftUI view. The view updates SettingsStore directly and applies
/// changes to the controller for immediate effect.
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    /// The controller for audio/keystroke state.
    private weak var controller: KeyPulseController?

    /// The preferences window instance.
    private var window: NSWindow?

    /// The SwiftUI hosting controller.
    private var hostingController: NSHostingController<PreferencesView>?

    /// Window frame autosave name for persistence.
    private let windowFrameName = "keypulse.preferences"

    /// Whether the window is currently visible.
    var isWindowVisible: Bool {
        return window?.isVisible ?? false
    }

    /// Called when settings change in the preferences window, so the menu bar
    /// can refresh its state.
    var onSettingsChanged: (() -> Void)?

    /// Creates a new preferences window controller.
    /// - Parameter controller: The KeyPulseController for applying settings.
    init(controller: KeyPulseController) {
        self.controller = controller
        super.init()
        setupWindow()
    }

    deinit {
        window?.delegate = nil
    }

    // MARK: - Window Management

    /// Sets up the preferences window with SwiftUI view bound to SettingsStore.
    private func setupWindow() {
        guard let controller = controller else { return }

        // Create the SwiftUI view
        let preferencesView = PreferencesView(
            controller: controller,
            settings: SettingsStore.shared,
            onSettingsChanged: { [weak self] in
                self?.onSettingsChanged?()
            }
        )

        // Create hosting controller
        hostingController = NSHostingController(rootView: preferencesView)
        guard let hostingController = hostingController else { return }

        // Create the window — 480x360, non-resizable
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // Configure window
        window.title = "KeyPulse Preferences"
        window.contentViewController = hostingController
        window.delegate = self
        window.setFrameAutosaveName(windowFrameName)
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
    }

    // MARK: - Public Methods

    /// Shows the preferences window, activating the app and bringing it to front.
    /// The view updates automatically via @ObservedObject — no manual recreation needed.
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hides the preferences window.
    func hideWindow() {
        window?.orderOut(nil)
    }

    /// Toggles the preferences window visibility.
    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of close to preserve state
        hideWindow()
        return false
    }
}

// MARK: - SwiftUI Views

/// SwiftUI view for the Preferences window content.
struct PreferencesView: View {
    /// The controller for applying settings changes.
    @ObservedObject var controller: KeyPulseController

    /// The settings store — single source of truth.
    @ObservedObject var settings: SettingsStore

    /// Callback to notify the app delegate that settings changed (for menu bar sync).
    private var onSettingsChanged: (() -> Void)?

    /// Whether to show the Reset All Settings confirmation alert.
    @State private var showResetConfirmation = false

    /// Initializes the preferences view with required dependencies.
    init(controller: KeyPulseController, settings: SettingsStore, onSettingsChanged: (() -> Void)? = nil) {
        self.controller = controller
        self.settings = settings
        self.onSettingsChanged = onSettingsChanged
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("General")
                }

            soundsTab
                .tabItem {
                    Image(systemName: "speaker.wave.2")
                    Text("Sounds")
                }

            advancedTab
                .tabItem {
                    Image(systemName: "wrench")
                    Text("Advanced")
                }
        }
        .padding()
        .frame(width: 460, height: 340)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Accessibility Permission") {
                HStack {
                    Image(systemName: controller.isAccessibilityPermissionGranted
                        ? "checkmark.circle.fill"
                        : "lock.fill")
                        .foregroundColor(controller.isAccessibilityPermissionGranted ? .green : .orange)
                    Text(controller.isAccessibilityPermissionGranted
                        ? "Granted"
                        : "Required")
                        .foregroundColor(controller.isAccessibilityPermissionGranted ? .secondary : .primary)
                }

                if !controller.isAccessibilityPermissionGranted {
                    Text("KeyPulse needs Accessibility permission to detect keystrokes.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Request Access…") {
                            KeyboardMonitor.requestAccessibilityPermission()
                        }
                        .help("Show the system permission dialog")

                        Button("Open System Settings") {
                            KeyboardMonitor.openAccessibilitySettings()
                        }
                        .help("Open System Settings > Privacy & Security > Accessibility")
                    }
                }
            }

            Divider()

            Toggle("Enabled", isOn: Binding(
                get: { settings.isEnabled },
                set: { newValue in
                    controller.isEnabled = newValue
                    settings.isEnabled = newValue
                    onSettingsChanged?()
                }
            ))
            .disabled(!controller.isAccessibilityPermissionGranted)
            .help(controller.isAccessibilityPermissionGranted
                ? "Process keystrokes and play sounds"
                : "Enable Accessibility permission first")

            Divider()

            Toggle("Launch at Login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    onSettingsChanged?()
                }
            ))
            .help("Automatically start KeyPulse when you log in")
        }
        .padding()
    }

    // MARK: - Sounds Tab

    private var soundsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Profile picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sound Profile")
                        .font(.headline)

                    Picker("Profile", selection: Binding(
                        get: { settings.profile },
                        set: { newProfile in
                            do {
                                try controller.setProfile(newProfile)
                                settings.profile = newProfile
                                onSettingsChanged?()
                            } catch {
                                controller.onError?(error)
                            }
                        }
                    )) {
                        Text("Linear").tag(SoundProfile.linear)
                        Text("Tactile").tag(SoundProfile.tactile)
                        Text("Clicky").tag(SoundProfile.clicky)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Divider()

                // Volume slider
                VStack(alignment: .leading, spacing: 6) {
                    Text("Volume")
                        .font(.headline)

                    HStack {
                        Slider(value: Binding(
                            get: { Double(settings.volume) },
                            set: { newValue in
                                let intValue = Int(newValue)
                                settings.volume = intValue
                                controller.setVolume(intValue)
                                onSettingsChanged?()
                            }
                        ), in: 0...100, step: 1)

                        Text("\(settings.volume)%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                Divider()

                // Toggles
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Mute", isOn: Binding(
                        get: { settings.isMuted },
                        set: { newValue in
                            settings.isMuted = newValue
                            controller.setMuted(newValue)
                            onSettingsChanged?()
                        }
                    ))

                    Toggle("Pitch Variation", isOn: Binding(
                        get: { settings.pitchRandomization },
                        set: { newValue in
                            settings.pitchRandomization = newValue
                            controller.setPitchRandomization(newValue)
                            onSettingsChanged?()
                        }
                    ))
                    .help("Randomly vary pitch by ±5% per keystroke")
                }

                Divider()

                // Test Sound button
                Button("Test Sound") {
                    controller.testPlay()
                }
                .disabled(settings.isMuted)
            }
            .padding()
        }
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show Debug Window button
            VStack(alignment: .leading, spacing: 6) {
                Text("Debugging")
                    .font(.headline)

                Button("Show Debug Window") {
                    NotificationCenter.default.post(
                        name: .showDebugWindow,
                        object: nil
                    )
                }
            }

            Divider()

            // Reset All Settings
            VStack(alignment: .leading, spacing: 6) {
                Text("Reset")
                    .font(.headline)

                Button("Reset All Settings") {
                    showResetConfirmation = true
                }
                .foregroundColor(.red)
                .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        performReset()
                    }
                } message: {
                    Text("This will reset all settings to their default values. KeyPulse will continue running with default settings.")
                }
            }

            Spacer()

            // Version label
            HStack {
                Spacer()
                Text("KeyPulse v0.1.0 (Build 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Actions

    /// Performs a full reset of all settings to defaults.
    private func performReset() {
        settings.resetToDefaults()
        controller.setVolume(settings.volume)
        controller.setMuted(settings.isMuted)
        controller.isEnabled = settings.isEnabled
        controller.setPitchRandomization(settings.pitchRandomization)
        onSettingsChanged?()
    }
}
