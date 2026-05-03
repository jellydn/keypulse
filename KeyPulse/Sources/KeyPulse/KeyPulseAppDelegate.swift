import AppKit
import os.log

// MARK: - Type-Safe Notification Names

extension NSNotification.Name {
    /// Posted when the Advanced tab's "Show Debug Window" button is clicked.
    static let showDebugWindow = NSNotification.Name("keypulse_showDebugWindow")
}

class KeyPulseAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: KeyPulseController?
    private var menuBarManager: MenuBarManager?
    private var debugWindowController: DebugWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private let settingsStore = SettingsStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupController()
        applySettingsToController()
        setupMenuBar()
        setupDebugWindow()
        setupPreferencesWindow()
        registerNotificationObservers()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard let controller = controller else { return }
        if !controller.isAccessibilityPermissionGranted {
            let granted = controller.recheckAccessibilityPermission()
            if granted {
                Logger.appDelegate.info("Accessibility permission granted — monitoring resumed")
                menuBarManager?.refresh()
            }
        }
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
            Logger.appDelegate.error("Cannot setup menu bar without controller")
            return
        }

        menuBarManager = MenuBarManager(controller: controller)

        // Sync initial launch at login state
        menuBarManager?.updateLaunchAtLoginState(settingsStore.launchAtLogin)

        // Set up callbacks for menu actions with settings persistence
        menuBarManager?.onEnabledChanged = { [weak self] enabled in
            Logger.appDelegate.debug("Enabled state changed to \(enabled)")
            self?.settingsStore.isEnabled = enabled
        }

        menuBarManager?.onProfileChanged = { [weak self] profile in
            Logger.appDelegate.debug("Profile changed to \(profile.displayName)")
            self?.settingsStore.profile = profile
        }

        menuBarManager?.onVolumeChanged = { [weak self] volume in
            Logger.appDelegate.debug("Volume changed to \(volume)%")
            self?.settingsStore.volume = volume
        }

        menuBarManager?.onMuteChanged = { [weak self] muted in
            Logger.appDelegate.debug("Mute state changed to \(muted)")
            self?.settingsStore.isMuted = muted
        }

        menuBarManager?.onPitchVariationChanged = { [weak self] enabled in
            Logger.appDelegate.debug("Pitch variation changed to \(enabled)")
            self?.settingsStore.pitchRandomization = enabled
        }

        menuBarManager?.onLaunchAtLoginChanged = { [weak self] enabled in
            Logger.appDelegate.debug("Launch at login changed to \(enabled)")
            guard let self = self else { return }
            // Attempt SMAppService registration synchronously
            self.settingsStore.launchAtLogin = enabled
            // Sync the menu state with the actual result (handles failure gracefully)
            let actualState = self.settingsStore.launchAtLogin
            self.menuBarManager?.updateLaunchAtLoginState(actualState)
        }

        menuBarManager?.onQuit = { [weak self] in
            Logger.appDelegate.info("Quit requested")
            self?.saveSettings()
        }

        menuBarManager?.onDebugWindowRequested = { [weak self] in
            Logger.appDelegate.debug("Debug window requested")
            self?.debugWindowController?.toggleWindow()
        }

        menuBarManager?.onPreferencesRequested = { [weak self] in
            Logger.appDelegate.debug("Preferences requested")
            self?.preferencesWindowController?.showWindow()
        }
    }

    private func setupDebugWindow() {
        guard let controller = controller else {
            Logger.appDelegate.error("Cannot setup debug window without controller")
            return
        }

        debugWindowController = DebugWindowController(controller: controller)
        Logger.appDelegate.info("Debug window controller initialized (Cmd+Opt+D to show)")
    }

    private func setupPreferencesWindow() {
        guard let controller = controller else {
            Logger.appDelegate.error("Cannot setup preferences window without controller")
            return
        }

        preferencesWindowController = PreferencesWindowController(controller: controller)

        // When settings change in Preferences, refresh the menu bar to stay in sync
        preferencesWindowController?.onSettingsChanged = { [weak self] in
            self?.menuBarManager?.refresh()
        }

        Logger.appDelegate.info("Preferences window controller initialized (Cmd+, to show)")
    }

    /// Registers notification observers for cross-component communication.
    /// For example, the Advanced tab's "Show Debug Window" button posts a notification.
    private func registerNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .showDebugWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.debugWindowController?.showWindow()
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
                Logger.appDelegate.error("Controller error: \(error.localizedDescription)")
            }

            // Start keyboard monitoring
            let started = controller?.start() ?? false

            if !started {
                Logger.appDelegate.info("Accessibility permission required — opening System Settings")

                // Open System Settings to Accessibility section
                KeyboardMonitor.openAccessibilitySettings()
            } else {
                Logger.appDelegate.info("Controller initialized and monitoring keyboard events")
            }
        } catch {
            Logger.appDelegate.error("Failed to initialize controller: \(error.localizedDescription)")
        }
    }

    private func applySettingsToController() {
        guard let controller = controller else { return }

        // Apply saved settings to the controller
        settingsStore.applyToController(controller)
        Logger.appDelegate.debug("Applied saved settings — profile: \(controller.currentProfile.displayName), volume: \(controller.volume)%, muted: \(controller.isMuted), enabled: \(controller.isEnabled)")
    }

    private func saveSettings() {
        guard let controller = controller else { return }
        settingsStore.saveFromController(controller)
        Logger.appDelegate.info("Settings saved")
    }
}
