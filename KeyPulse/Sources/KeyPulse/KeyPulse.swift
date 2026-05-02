import AppKit

@main
struct KeyPulse {
    static func main() {
        let app = NSApplication.shared
        let delegate = KeyPulseAppDelegate()
        app.delegate = delegate
        app.run()
    }
}
