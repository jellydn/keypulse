import Foundation
import CoreGraphics
import Carbon
import AppKit

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
    /// - Parameter keyCode: The virtual key code (Carbon key code, e.g., kVK_Space = 49)
    typealias KeyDownHandler = (_ keyCode: UInt16) -> Void

    /// Called whenever a key-down event is detected.
    var onKeyDown: KeyDownHandler?

    /// The event tap reference.
    private var eventTap: CFMachPort?

    /// The run loop source for the event tap.
    private var runLoopSource: CFRunLoopSource?

    /// Whether the monitor is currently active.
    private(set) var isMonitoring = false

    /// Tracks the last modifier flags state to detect actual changes (not repeated events).
    /// Used for debouncing flagsChanged events so each modifier press fires once.
    private var lastModifierFlags: CGEventFlags = []

    /// Callback for modifier flag changes. Called whenever shift/cmd/option/ctrl state changes.
    var onFlagsChanged: ((_ flags: CGEventFlags) -> Void)?

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
            print("KeyboardMonitor: Failed to construct accessibility settings URL")
            return
        }
        NSWorkspace.shared.open(url)
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
            print("KeyboardMonitor: Accessibility permission not granted")
            return false
        }

        // Create the event tap
        // We use kCGEventTapOptionListenOnly to avoid intercepting events (we only observe)
        // Include both keyDown and flagsChanged to capture regular keys AND modifier-only presses
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
                // Cast refcon back to KeyboardMonitor instance
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("KeyboardMonitor: Failed to create event tap")
            return false
        }

        self.eventTap = tap

        // Create run loop source
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        // Add to run loop and enable
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isMonitoring = true
        print("KeyboardMonitor: Started monitoring keyboard events")
        return true
    }

    /// Stops monitoring keyboard events.
    func stop() {
        guard isMonitoring else { return }

        // Disable and clean up event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        // Remove from run loop
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        // Invalidate the tap
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }

        runLoopSource = nil
        eventTap = nil
        isMonitoring = false
        print("KeyboardMonitor: Stopped monitoring keyboard events")
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
        // CGEvent key codes match Carbon virtual key codes
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Call the handler on the main thread
        DispatchQueue.main.async { [weak self] in
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

        // For modifier events, use a special key code to indicate it's a modifier
        // We'll use 0xFF (255) as a sentinel value for modifier-only events
        // This is outside the normal key code range (0-127)
        let modifierKeyCode: UInt16 = 0xFF

        // Call the handlers on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.onKeyDown?(modifierKeyCode)
            self?.onFlagsChanged?(currentFlags)
        }
    }

    /// Returns the current modifier flags state.
    /// Useful for getting the initial state when the debug window opens.
    var currentModifierFlags: CGEventFlags {
        return lastModifierFlags
    }
}
