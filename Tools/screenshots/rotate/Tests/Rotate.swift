import XCTest

/// Turns the booted simulator to landscape or portrait. The Simulator's rotate shortcut can't be scripted,
/// but a UI test can set the device orientation, and it stays set after the test ends.
/// Choose with TEST_RUNNER_TARGET_ORIENTATION=landscape|portrait when running xcodebuild.
final class Rotate: XCTestCase {
    func testRotate() {
        let target = ProcessInfo.processInfo.environment["TARGET_ORIENTATION"] ?? "landscape"
        XCUIDevice.shared.orientation = target == "portrait" ? .portrait : .landscapeLeft
        Thread.sleep(forTimeInterval: 2)
    }
}
