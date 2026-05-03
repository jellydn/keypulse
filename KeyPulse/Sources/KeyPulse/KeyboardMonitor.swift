import Foundation
import CoreGraphics
import AppKit
import os.log

/// Global keyboard event monitor using CGEventTap.
///
/// **Implementation Note: CGEventTap vs IOHIDManager**
/// We chose `CGEventTap` over `IOHIDManager` for the following reasons:
/// - CGEventTap provides high-level key event information (key codes, flags) without requiring
///   complex HID device enumeration and value parsing
/// - It integrates well with the macOS event system and respects system accessibility settings
/// - IOHIDManager is lower-level and better suited for raw hardware access (e.g., game controllers,
///   custom keyboards) but requires more boilerplate for simple key detection
/// - CGEventTap allows us to monitor events without intercepting them (kCGEventTapOptionListenOnly),
///   making it safer for a background audio app that shouldn't interfere with input
///
/// **Trade-offs:**
/// - CGEventTap requires Accessibility permission (AXIsProcessTrusted)
/// - Events may be delayed under heavy system load (but still well under our 20ms latency target)
/// - Some secure input fields (password dialogs) may suppress events, which is acceptable behavior
final class KeyboardMonitor {
    /// Callback type for key-down events.
    /// - Parameter keyCode: The virtual key code (e.g., Space = 49).
    typealias KeyDownHandler = (_ keyCode: UInt16) -> Void

    /// Called whenever a key-down event is detected.
    var onKeyDown: KeyDownHandler?

    /// The event tap reference.
    private var eventTap: CFMachPort?

    /// The run loop source for the event tap.
    private var runLoopSource: CFRunLoopSource?

    /// Whether the monitor is currently active.
    private(set) var isMonitoring = false

    /// Observer token for system sleep/wake notifications.
    private var wakeObserver: NSObjectProtocol?

    /// Timer for periodic event tap health checks.
    private var healthCheckTimer: Timer?

    /// Tracks the last modifier flags state to detect actual changes (not repeated events).
    /// Used for debouncing flagsChanged events so each modifier press fires once.
    private var lastModifierFlags: CGEventFlags = []

    /// Whether the last key-down event was a modifier (flagsChanged) event.
    /// Used instead of a sentinel key code (0xFF) to avoid overlap with real HID key codes.
    private(set) var isLastEventModifier = false

    /// Whether secure text input is detected (password fields, credit card forms, etc.).
    /// When true, keystroke sounds are suppressed to protect user privacy.
    private(set) var isSecureInputDetected = false

    /// Flag bit for secure text input detection in CGEventFlags.
    /// Defined as `kCGEventFlagMaskSecureInput` (bit 16) in CoreGraphics private headers.
    private let secureInputFlag: CGEventFlags = CGEventFlags(rawValue: 1 << 16)

    /// Callback for modifier flag changes. Called whenever shift/cmd/option/ctrl state changes.
    var onFlagsChanged: ((_ flags: CGEventFlags) -> Void)?

    /// Dedicated serial queue for keystroke → audio dispatch.
    /// Isolates audio playback from main thread jank, preventing keystroke
    /// queueing when the main thread is blocked by animations or sheet presentation.
    private let audioDispatchQueue = DispatchQueue(
        label: "com.keypulse.audio-dispatch",
        qos: .userInteractive
    )

    /// Creates a new keyboard monitor.
    /// Note: Call `start()` to begin monitoring after checking/requesting accessibility permission.
    init() {}

    deinit {
        stop()
    }

    // MARK: - Permission Handling

    /// Checks if the app has accessibility permission.
    /// - Returns: True if accessibility is enabled for this app.
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Requests accessibility permission from the user.
    /// This will show the system dialog if permission hasn't been granted.
    /// The user must manually enable KeyPulse in System Settings > Privacy & Security > Accessibility.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Opens System Settings to the Accessibility section for the user to manually enable permission.
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            Logger.keyboardMonitor.error("Failed to construct accessibility settings URL")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Re-checks accessibility permission and restarts monitoring if newly granted.
    /// Call this when the user returns from System Settings.
    /// - Returns: True if permission is now granted and monitoring is active.
    func recheckPermissionAndRestart() -> Bool {
        guard !isMonitoring else { return true }
        guard Self.checkAccessibilityPermission() else { return false }
        return start()
    }

    // MARK: - Monitoring Control

    /// Starts monitoring keyboard events.
    /// - Returns: True if monitoring started successfully, false if accessibility permission is missing
    ///           or the event tap couldn't be created.
    @discardableResult
    func start() -> Bool {
        guard !isMonitoring else { return true }

        // Check accessibility permission first
        guard Self.checkAccessibilityPermission() else {
            Logger.keyboardMonitor.info("Accessibility permission not granted")
            return false
        }

        // Create the event tap
        guard createEventTap() else {
            Logger.keyboardMonitor.error("Failed to create event tap")
            return false
        }

        // Register for system wake notifications to restart tap after sleep
        registerWakeObserver()

        // Start periodic health check (every 30 seconds) to detect tap invalidation
        startHealthCheckTimer()

        isMonitoring = true
        Logger.keyboardMonitor.info("Started monitoring keyboard events")
        return true
    }

    /// Creates and registers the CGEventTap. Extracted so it can be called on wake.
    private func createEventTap() -> Bool {
        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    /// Registers for system wake notifications to restart the event tap.
    /// CGEventTaps are torn down during system sleep and must be re-created on wake.
    /// Uses exponential backoff (1s, 2s, 4s) to recover from transient system state after wake.
    private func registerWakeObserver() {
        // Remove any existing observer first
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isMonitoring else { return }

            Logger.keyboardMonitor.info("System woke from sleep — restarting event tap")

            // Tear down the old (now-invalid) tap
            self.tearDownEventTap()

            // Attempt to re-create the tap with exponential backoff
            self.retryCreateEventTap(maxAttempts: 3, baseDelayMs: 1000)
        }
    }

    /// Attempts to create the event tap with exponential backoff retry.
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts.
    ///   - baseDelayMs: Initial delay in milliseconds (doubles each attempt).
    private func retryCreateEventTap(maxAttempts: Int, baseDelayMs: Int) {
        for attempt in 1...maxAttempts {
            if self.createEventTap() {
                Logger.keyboardMonitor.info("Event tap restarted after wake (attempt \(attempt))")
                return
            }

            if attempt < maxAttempts {
                let delayMs = baseDelayMs * Int(pow(2.0, Double(attempt - 1)))
                Logger.keyboardMonitor.info("Event tap restart attempt \(attempt) failed — retrying in \(delayMs)ms")
                Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
            }
        }

        Logger.keyboardMonitor.error("Failed to restart event tap after \(maxAttempts) attempts — disabling monitoring")
        self.isMonitoring = false
    }

    /// Stops monitoring keyboard events.
    func stop() {
        guard isMonitoring else { return }

        // Stop health check timer
        stopHealthCheckTimer()

        // Remove wake observer
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }

        // Tear down the event tap
        tearDownEventTap()

        isMonitoring = false
        Logger.keyboardMonitor.info("Stopped monitoring keyboard events")
    }

    /// Tears down the event tap (disable, remove from run loop, invalidate).
    /// Safe to call multiple times; used both for normal stop and sleep/wake restart.
    private func tearDownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }

        runLoopSource = nil
        eventTap = nil
    }

    // MARK: - Health Check

    /// Starts a 30-second interval timer that checks whether the CGEventTap is still valid.
    /// If the tap becomes invalid (e.g., due to permissions revocation or system policy change),
    /// the monitor is stopped and the user loses feedback. The health check ensures we can
    /// detect this condition and attempt recovery.
    private func startHealthCheckTimer() {
        stopHealthCheckTimer()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isMonitoring, let tap = self.eventTap else { return }

            if !CFMachPortIsValid(tap) {
                Logger.keyboardMonitor.error("Event tap became invalid — attempting restart")
                self.tearDownEventTap()
                if !self.createEventTap() {
                    Logger.keyboardMonitor.error("Failed to recreate invalid event tap — disabling monitoring")
                    self.isMonitoring = false
                    self.stopHealthCheckTimer()
                }
            }
        }
    }

    /// Stops and invalidates the health check timer.
    private func stopHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    // MARK: - Event Handling

    /// Handles a CGEvent from the event tap.
    /// - Returns: The event (unmodified since we use listen-only mode).
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        switch type {
        case .keyDown:
            handleKeyDownEvent(event)
        case .flagsChanged:
            handleFlagsChangedEvent(event)
        default:
            break
        }

        // Return the event unmodified (listen-only mode)
        return Unmanaged.passUnretained(event)
    }

    /// Handles a key-down event (regular keystrokes).
    private func handleKeyDownEvent(_ event: CGEvent) {
        // Extract the key code from the event
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Regular keystrokes are never modifier events
        isLastEventModifier = false

        // Check for secure text input (password fields, credit card forms, etc.)
        // When detected, suppress sounds to avoid leaking sensitive input patterns.
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        let isSecureInput = sessionFlags.contains(secureInputFlag)
        isSecureInputDetected = isSecureInput

        guard !isSecureInput else {
            Logger.keyboardMonitor.info("Secure input detected — suppressing keystroke sounds")
            return
        }

        // Dispatch on the dedicated audio queue to isolate playback from main thread jank
        audioDispatchQueue.async { [weak self] in
            self?.onKeyDown?(keyCode)
        }
    }

    /// Handles a flags-changed event (modifier-only presses: shift, cmd, option, ctrl).
    /// Uses debouncing so each modifier press fires once (not repeatedly while held).
    private func handleFlagsChangedEvent(_ event: CGEvent) {
        let currentFlags = event.flags

        // Debounce: only trigger if flags actually changed (not just repeated events)
        // When a modifier is pressed, flags go from [] to [mask]
        // When released, flags go from [mask] to []
        // We trigger on any change to provide feedback for both press and release
        let flagsActuallyChanged = currentFlags != lastModifierFlags
        lastModifierFlags = currentFlags

        guard flagsActuallyChanged else {
            return
        }

        // For modifier events, we mark isLastEventModifier so consumers can distinguish
        // modifier-only presses from regular keystrokes. A separate boolean flag avoids
        // sentinel key code 0xFF which could overlap with real extended HID key codes.
        let anyKeyCode: UInt16 = 0  // Arbitrary; consumers check isLastEventModifier instead

        // Dispatch on the dedicated audio queue to isolate playback from main thread jank
        audioDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            self.isLastEventModifier = true
            self.onKeyDown?(anyKeyCode)
            self.onFlagsChanged?(currentFlags)
        }
    }

    /// Returns the current modifier flags state.
    /// Useful for getting the initial state when the debug window opens.
    var currentModifierFlags: CGEventFlags {
        return lastModifierFlags
    }
}
