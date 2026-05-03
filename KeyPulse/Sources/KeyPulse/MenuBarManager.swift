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

    /// Header menu item (non-clickable, shows app name + current state)
    private var headerMenuItem: NSMenuItem?

    /// Cached icons for each state
    private var cachedIconEnabledUnmuted: NSImage?
    private var cachedIconDisabled: NSImage?
    private var cachedIconMuted: NSImage?
    private var cachedIconNoPermission: NSImage?

    /// The main menu (shown on left-click)
    private var mainMenu: NSMenu?

    /// The alternate menu (shown on right-click or option-click)
    private var alternateMenu: NSMenu?

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

    // MARK: - Icon State (Testable Pure Function)

    /// Returns the SF Symbol name for the given state combination.
    /// This is a pure function — no AppKit dependencies — for easy unit testing.
    /// - Parameters:
    ///   - enabled: Whether KeyPulse is processing keystrokes.
    ///   - muted: Whether audio is muted.
    ///   - permissionGranted: Whether accessibility permission is granted.
    /// - Returns: The SF Symbol name string.
    static func iconSymbolName(enabled: Bool, muted: Bool, permissionGranted: Bool) -> String {
        guard permissionGranted else { return "keyboard" }
        switch (enabled, muted) {
        case (true, false): return "keyboard.fill"
        case (false, _): return "keyboard"
        case (true, true): return "keyboard"
        }
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set initial icon
        updateIcon()

        // Build menus
        mainMenu = buildMainMenu()
        alternateMenu = buildAlternateMenu()
        statusItem?.menu = mainMenu

        // Handle right-click and option-click via sendAction
        statusItem?.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        statusItem?.button?.action = #selector(handleStatusItemClick)
        statusItem?.button?.target = self

        // Sync initial state
        syncMenuState()
    }

    /// Handles status item clicks to swap between main and alternate menus.
    /// Right-click or option+left-click shows the compact alternate menu.
    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }

        let isRightClick = event.type == .rightMouseDown
        let isOptionClick = event.type == .leftMouseDown && event.modifierFlags.contains(.option)

        if isRightClick || isOptionClick {
            statusItem?.menu = alternateMenu
        } else {
            statusItem?.menu = mainMenu
        }

        // Perform the click to open the selected menu
        statusItem?.button?.performClick(nil)
    }

    /// Builds the main menu bar menu (shown on left-click).
    /// - Returns: The configured NSMenu.
    private func buildMainMenu() -> NSMenu {
        let menu = NSMenu()

        // Header item (non-clickable, shows app status at a glance)
        let headerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        headerMenuItem = headerItem
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

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

    /// Builds the alternate menu (shown on right-click or option-click).
    /// Compact menu with just a Quit item.
    /// - Returns: The configured NSMenu.
    private func buildAlternateMenu() -> NSMenu {
        let menu = NSMenu()

        let quitItem = NSMenuItem(
            title: "Quit KeyPulse",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Icon Generation

    /// Generates the SF Symbol-based icon for the current state.
    /// Icons are cached to avoid repeated NSImage compositing.
    /// - Returns: A template NSImage for the menu bar.
    private func generateIcon() -> NSImage? {
        guard let controller = controller else { return nil }

        let isEnabled = controller.isEnabled
        let isMuted = controller.isMuted
        let hasPermission = controller.isAccessibilityPermissionGranted

        // No permission: keyboard outline with exclamationmark overlay
        guard hasPermission else {
            if let cached = cachedIconNoPermission { return cached }
            let size = NSSize(width: 18, height: 18)
            let image = NSImage(size: size, flipped: false) { rect in
                guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                if let keyboardImage = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) {
                    ctx.saveGState()
                    keyboardImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    ctx.restoreGState()
                }
                let overlaySize = NSSize(width: 9, height: 9)
                let overlayRect = NSRect(
                    x: rect.maxX - overlaySize.width + 1,
                    y: rect.minY + 1,
                    width: overlaySize.width,
                    height: overlaySize.height
                )
                if let exclaimImage = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil) {
                    exclaimImage.draw(in: overlayRect, from: .zero, operation: .sourceOver, fraction: 0.9)
                }
                return true
            }
            image.isTemplate = true
            cachedIconNoPermission = image
            return image
        }

        if isMuted {
            // Return cached muted icon
            if let cached = cachedIconMuted { return cached }
            // Generate muted icon: keyboard + nosign overlay
            let size = NSSize(width: 18, height: 18)
            let image = NSImage(size: size, flipped: false) { rect in
                guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

                // Draw keyboard outline
                if let keyboardImage = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) {
                    ctx.saveGState()
                    keyboardImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    ctx.restoreGState()
                }

                // Draw nosign overlay at bottom-right (smaller, slightly offset)
                let overlaySize = NSSize(width: 9, height: 9)
                let overlayRect = NSRect(
                    x: rect.maxX - overlaySize.width + 1,
                    y: rect.minY + 1,
                    width: overlaySize.width,
                    height: overlaySize.height
                )
                if let slashImage = NSImage(systemSymbolName: "nosign", accessibilityDescription: nil) {
                    slashImage.draw(in: overlayRect, from: .zero, operation: .sourceOver, fraction: 0.9)
                }

                return true
            }
            image.isTemplate = true
            cachedIconMuted = image
            return image
        }

        if !isEnabled {
            // Return cached disabled icon
            if let cached = cachedIconDisabled { return cached }
            let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyPulse disabled")
            image?.isTemplate = true
            cachedIconDisabled = image
            return image
        }

        // Enabled + unmuted: keyboard.fill
        if let cached = cachedIconEnabledUnmuted { return cached }
        let image = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: "KeyPulse enabled")
        image?.isTemplate = true
        cachedIconEnabledUnmuted = image
        return image
    }

    /// Resets the icon cache so the next call to generateIcon() creates fresh images.
    /// Called when the menu is rebuilt (e.g., on SettingsStore reset).
    func resetIconCache() {
        cachedIconEnabledUnmuted = nil
        cachedIconDisabled = nil
        cachedIconMuted = nil
        cachedIconNoPermission = nil
    }

    // MARK: - State Sync

    /// Synchronizes the menu state with the controller state.
    func syncMenuState() {
        guard let controller = controller else { return }

        // Update icon to reflect current state
        updateIcon()

        // Update header to reflect current state
        updateHeader()

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

    /// Updates the menu bar icon to reflect the current controller state.
    private func updateIcon() {
        guard let button = statusItem?.button else { return }

        if let icon = generateIcon() {
            button.image = icon
            button.imagePosition = .imageOnly
        } else {
            button.title = "KP"
        }

        // Update accessibility label
        updateAccessibilityLabel()
    }

    /// Updates the accessibility label on the status item button.
    private func updateAccessibilityLabel() {
        guard let controller = controller else { return }
        let profileName = controller.currentProfile.displayName
        let volume = controller.volume
        let muteStatus = controller.isMuted ? "muted" : "active"
        let enabledStatus = controller.isEnabled ? "enabled" : "disabled"
        let permissionStatus = controller.isAccessibilityPermissionGranted ? "permission granted" : "permission required"
        statusItem?.button?.setAccessibilityLabel("KeyPulse - \(profileName) profile, \(volume)% volume, \(muteStatus), \(enabledStatus), \(permissionStatus)")
    }

    /// Updates the header menu item with the current controller state.
    private func updateHeader() {
        guard let controller = controller,
              let headerItem = headerMenuItem else { return }

        let profileName = controller.currentProfile.displayName
        let volume = controller.volume
        let muteText = controller.isMuted ? "Muted" : "Active"
        let enabledText = controller.isEnabled ? "" : " — Disabled"
        let permissionText = controller.isAccessibilityPermissionGranted ? "" : " — No Permission"

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        // Primary line: "KeyPulse - <Profile>"
        let primary = NSAttributedString(
            string: "KeyPulse — \(profileName)\(enabledText)\(permissionText)",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize),
                .paragraphStyle: paragraphStyle
            ]
        )

        // Secondary line: volume and mute status
        let secondary = NSAttributedString(
            string: "\n\(volume)% — \(muteText)",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        let combined = NSMutableAttributedString()
        combined.append(primary)
        combined.append(secondary)

        headerItem.attributedTitle = combined
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
        syncMenuState()
        onEnabledChanged?(newState)
    }

    @objc private func profileSelected(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? SoundProfile,
              let controller = controller else { return }

        do {
            try controller.setProfile(profile)
            syncMenuState()
            onProfileChanged?(profile)
        } catch {
            Logger.menuBarManager.error("Failed to change profile: \(error.localizedDescription)")
            // Revert to match actual (unchanged) engine state
            syncMenuState()
            // Propagate error to app delegate for user-facing alert
            controller.onError?(error)
        }
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        guard let controller = controller else { return }
        let volume = sender.integerValue
        controller.setVolume(volume)
        syncMenuState()
        onVolumeChanged?(volume)
    }

    @objc private func toggleMute() {
        guard let controller = controller else { return }
        let newState = !controller.isMuted
        controller.setMuted(newState)
        syncMenuState()
        onMuteChanged?(newState)
    }

    @objc private func togglePitchVariation() {
        guard let controller = controller else { return }
        let newState = !controller.pitchRandomization
        controller.setPitchRandomization(newState)
        syncMenuState()
        onPitchVariationChanged?(newState)
    }

    @objc private func toggleLaunchAtLogin() {
        // Delegate to the app delegate which handles SMAppService registration.
        // The callback is responsible for updating the menu state via
        // updateLaunchAtLoginState() after the registration attempt completes
        // (success or failure), avoiding an optimistic flicker.
        let currentState = launchAtLoginMenuItem?.state == .on
        let newState = !currentState
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
