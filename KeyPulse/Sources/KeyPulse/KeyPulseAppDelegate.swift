import AppKit
import Carbon

class KeyPulseAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var controller: KeyPulseController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "KP"

        let menu = NSMenu()

        let quitItem = NSMenuItem(
            title: "Quit KeyPulse",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
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
