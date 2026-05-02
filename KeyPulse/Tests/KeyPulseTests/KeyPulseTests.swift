import XCTest
@testable import KeyPulse

final class KeyPulseTests: XCTestCase {
    func testAppDelegateInitialization() {
        let delegate = KeyPulseAppDelegate()
        XCTAssertNotNil(delegate)
    }
}