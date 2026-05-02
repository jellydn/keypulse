import AppKit
import Carbon

class KeyPulseAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: KeyPulseController?
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupController()
        setupMenuBar()
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

        // Set up callbacks for menu actions (for logging/debugging)
        menuBarManager?.onEnabledChanged = { enabled in
            print("KeyPulse: Enabled state changed to \(enabled)")
        }

        menuBarManager?.onProfileChanged = { profile in
            print("KeyPulse: Profile changed to \(profile.displayName)")
        }

        menuBarManager?.onVolumeChanged = { volume in
            print("KeyPulse: Volume changed to \(volume)%")
        }

        menuBarManager?.onMuteChanged = { muted in
            print("KeyPulse: Mute state changed to \(muted)")
        }

        menuBarManager?.onQuit = {
            print("KeyPulse: Quit requested")
        }
    }

    private func setupController() {
        do {
            // Initialize the controller with default linear profile
            controller = try KeyPulseController(initialProfile: .linear)

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
}
