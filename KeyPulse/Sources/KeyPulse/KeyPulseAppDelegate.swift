import AppKit
import Carbon

class KeyPulseAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: KeyPulseController?
    private var menuBarManager: MenuBarManager?
    private let settingsStore = SettingsStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupController()
        applySettingsToController()
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save settings before quitting
        saveSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenuBar() {
        guard let controller = controller else {
            print("KeyPulse: Cannot setup menu bar without controller")
            return
        }

        menuBarManager = MenuBarManager(controller: controller)

        // Set up callbacks for menu actions with settings persistence
        menuBarManager?.onEnabledChanged = { [weak self] enabled in
            print("KeyPulse: Enabled state changed to \(enabled)")
            self?.settingsStore.isEnabled = enabled
        }

        menuBarManager?.onProfileChanged = { [weak self] profile in
            print("KeyPulse: Profile changed to \(profile.displayName)")
            self?.settingsStore.profile = profile
        }

        menuBarManager?.onVolumeChanged = { [weak self] volume in
            print("KeyPulse: Volume changed to \(volume)%")
            self?.settingsStore.volume = volume
        }

        menuBarManager?.onMuteChanged = { [weak self] muted in
            print("KeyPulse: Mute state changed to \(muted)")
            self?.settingsStore.isMuted = muted
        }

        menuBarManager?.onPitchVariationChanged = { [weak self] enabled in
            print("KeyPulse: Pitch variation changed to \(enabled)")
            self?.settingsStore.pitchRandomization = enabled
        }

        menuBarManager?.onQuit = { [weak self] in
            print("KeyPulse: Quit requested")
            self?.saveSettings()
        }
    }

    private func setupController() {
        do {
            // Load saved profile or use default
            let savedProfile = settingsStore.profile

            // Initialize the controller with saved profile
            controller = try KeyPulseController(initialProfile: savedProfile)

            // Set up error handling
            controller?.onError = { error in
                print("KeyPulseController error: \(error)")
            }

            // Start keyboard monitoring
            let started = controller?.start() ?? false

            if !started {
                // Accessibility permission not granted - could show a UI prompt here
                print("KeyPulse: Accessibility permission required. Please grant permission in System Settings > Privacy & Security > Accessibility.")

                // Open System Settings to Accessibility section
                KeyboardMonitor.openAccessibilitySettings()
            } else {
                print("KeyPulse: Controller initialized and monitoring keyboard events")
            }
        } catch {
            print("KeyPulse: Failed to initialize controller: \(error)")
        }
    }

    private func applySettingsToController() {
        guard let controller = controller else { return }

        // Apply saved settings to the controller
        settingsStore.applyToController(controller)
        print("KeyPulse: Applied saved settings - profile: \(controller.currentProfile.displayName), volume: \(controller.volume)%, muted: \(controller.isMuted), enabled: \(controller.isEnabled), pitchVariation: \(controller.pitchRandomization)")
    }

    private func saveSettings() {
        guard let controller = controller else { return }
        settingsStore.saveFromController(controller)
        print("KeyPulse: Settings saved")
    }
}
