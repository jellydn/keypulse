import AppKit
import os.log

/// Manages the menu bar UI including status item, menu controls, and icon.
final class MenuBarManager {
    /// The status bar item
    private var statusItem: NSStatusItem?

    /// Reference to the controller for state updates
    private weak var controller: KeyPulseController?

    /// Menu items that need to be updated dynamically
    private var enabledMenuItem: NSMenuItem?
    private var muteMenuItem: NSMenuItem?
    private var pitchVariationMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var volumeSliderItem: NSMenuItem?
    private var volumeSlider: NSSlider?
    private var profileMenuItems: [SoundProfile: NSMenuItem] = [:]

    /// Callbacks for menu actions
    var onEnabledChanged: ((Bool) -> Void)?
    var onProfileChanged: ((SoundProfile) -> Void)?
    var onVolumeChanged: ((Int) -> Void)?
    var onMuteChanged: ((Bool) -> Void)?
    var onPitchVariationChanged: ((Bool) -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?
    var onDebugWindowRequested: (() -> Void)?
    var onPreferencesRequested: (() -> Void)?
    var onQuit: (() -> Void)?

    /// Creates a new menu bar manager.
    /// - Parameter controller: The KeyPulseController for state access.
    init(controller: KeyPulseController) {
        self.controller = controller
        setupMenuBar()
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Create template icon or fallback to text
        if let icon = createMenuBarIcon() {
            statusItem?.button?.image = icon
            statusItem?.button?.imagePosition = .imageOnly
        } else {
            statusItem?.button?.title = "KP"
        }

        // Build the menu
        statusItem?.menu = buildMenu()

        // Sync initial state
        syncMenuState()
    }

    /// Creates a programmatic template icon for the menu bar.
    /// - Returns: A 18x18 template NSImage representing a keyboard key.
    private func createMenuBarIcon() -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard NSGraphicsContext.current?.cgContext != nil else { return false }

            // Draw key outline (rounded rectangle)
            let keyRect = CGRect(x: 1, y: 1, width: 16, height: 16)
            let path = NSBezierPath(roundedRect: keyRect, xRadius: 3, yRadius: 3)

            // Fill with black (becomes template color when tinted)
            NSColor.black.setFill()
            path.fill()

            // Draw inner rectangle for key face
            let innerRect = CGRect(x: 4, y: 4, width: 10, height: 10)
            let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 1.5, yRadius: 1.5)
            NSColor.black.setFill()
            innerPath.fill()

            return true
        }

        // Set as template image so macOS tints it for light/dark mode
        image.isTemplate = true

        return image
    }

    /// Builds the complete menu bar menu.
    /// - Returns: The configured NSMenu.
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Enabled toggle
        let enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledMenuItem = enabledItem
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())

        // Profile submenu
        let profileItem = NSMenuItem(title: "Profile", action: nil, keyEquivalent: "")
        let profileSubmenu = NSMenu()

        for profile in SoundProfile.allCases {
            let item = NSMenuItem(
                title: profile.displayName,
                action: #selector(profileSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile
            profileMenuItems[profile] = item
            profileSubmenu.addItem(item)
        }

        profileItem.submenu = profileSubmenu
        menu.addItem(profileItem)

        menu.addItem(NSMenuItem.separator())

        // Volume slider
        let volumeItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        let sliderContainer = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 24))

        let slider = NSSlider(frame: NSRect(x: 16, y: 2, width: 128, height: 20))
        slider.minValue = 0
        slider.maxValue = 100
        slider.integerValue = controller?.volume ?? 50
        slider.target = self
        slider.action = #selector(volumeChanged(_:))
        slider.numberOfTickMarks = 0
        slider.sliderType = .linear
        slider.trackFillColor = .controlAccentColor

        sliderContainer.addSubview(slider)
        volumeSlider = slider
        volumeItem.view = sliderContainer
        volumeSliderItem = volumeItem

        menu.addItem(volumeItem)

        // Mute toggle
        let muteItem = NSMenuItem(
            title: "Mute",
            action: #selector(toggleMute),
            keyEquivalent: ""
        )
        muteItem.target = self
        muteMenuItem = muteItem
        menu.addItem(muteItem)

        // Pitch Variation toggle
        let pitchItem = NSMenuItem(
            title: "Pitch Variation",
            action: #selector(togglePitchVariation),
            keyEquivalent: ""
        )
        pitchItem.target = self
        pitchVariationMenuItem = pitchItem
        menu.addItem(pitchItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login toggle
        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        launchAtLoginMenuItem = loginItem
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences...
        let preferencesMenuItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesMenuItem.target = self
        menu.addItem(preferencesMenuItem)

        // Debug Window
        let debugMenuItem = NSMenuItem(
            title: "Debug Window",
            action: #selector(showDebugWindow),
            keyEquivalent: "d"
        )
        debugMenuItem.target = self
        debugMenuItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(debugMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit KeyPulse",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - State Sync

    /// Synchronizes the menu state with the controller state.
    func syncMenuState() {
        guard let controller = controller else { return }

        // Update enabled state
        enabledMenuItem?.state = controller.isEnabled ? .on : .off

        // Update profile checkmarks
        for (profile, item) in profileMenuItems {
            item.state = (controller.currentProfile == profile) ? .on : .off
        }

        // Update volume slider
        volumeSlider?.integerValue = controller.volume

        // Update mute state
        muteMenuItem?.state = controller.isMuted ? .on : .off

        // Update pitch variation state
        pitchVariationMenuItem?.state = controller.pitchRandomization ? .on : .off
    }

    /// Updates the Launch at Login menu item state.
    /// - Parameter enabled: Whether launch at login is enabled.
    func updateLaunchAtLoginState(_ enabled: Bool) {
        launchAtLoginMenuItem?.state = enabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        guard let controller = controller else { return }
        let newState = !controller.isEnabled
        controller.isEnabled = newState
        enabledMenuItem?.state = newState ? .on : .off
        onEnabledChanged?(newState)
    }

    @objc private func profileSelected(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? SoundProfile,
              let controller = controller else { return }

        do {
            try controller.setProfile(profile)
            // Update checkmarks
            for (p, item) in profileMenuItems {
                item.state = (p == profile) ? .on : .off
            }
            onProfileChanged?(profile)
        } catch {
            Logger.menuBarManager.error("Failed to change profile: \(error.localizedDescription)")
            // Revert checkmarks to match actual (unchanged) engine state
            for (p, item) in profileMenuItems {
                item.state = (p == controller.currentProfile) ? .on : .off
            }
            // Propagate error to app delegate for user-facing alert
            controller.onError?(error)
        }
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        guard let controller = controller else { return }
        let volume = sender.integerValue
        controller.setVolume(volume)
        onVolumeChanged?(volume)
    }

    @objc private func toggleMute() {
        guard let controller = controller else { return }
        let newState = !controller.isMuted
        controller.setMuted(newState)
        muteMenuItem?.state = newState ? .on : .off
        onMuteChanged?(newState)
    }

    @objc private func togglePitchVariation() {
        guard let controller = controller else { return }
        let newState = !controller.pitchRandomization
        controller.setPitchRandomization(newState)
        pitchVariationMenuItem?.state = newState ? .on : .off
        onPitchVariationChanged?(newState)
    }

    @objc private func toggleLaunchAtLogin() {
        // Get current state from UserDefaults/settings store via callback
        // The actual state handling is done by the app delegate
        let currentState = launchAtLoginMenuItem?.state == .on
        let newState = !currentState
        launchAtLoginMenuItem?.state = newState ? .on : .off
        onLaunchAtLoginChanged?(newState)
    }

    @objc private func showPreferences() {
        onPreferencesRequested?()
    }

    @objc private func showDebugWindow() {
        onDebugWindowRequested?()
    }

    @objc private func quitApp() {
        onQuit?()
        NSApp.terminate(nil)
    }

    // MARK: - Public API

    /// Updates the menu to reflect current controller state.
    /// Call this after external state changes.
    func refresh() {
        syncMenuState()
    }
}
