import ServiceManagement
import XCTest
@testable import PsPaste

/// Launch-at-login (Task 15-A): the controller decides and toggles over an
/// injectable login item; SMAppService itself is never touched in tests.
final class LaunchAtLoginControllerTests: XCTestCase {

    private struct FakeError: Error {}

    private final class MockLoginItem: LaunchAtLoginController.LoginItemManaging {
        var status: SMAppService.Status
        private(set) var registerCalls = 0
        private(set) var unregisterCalls = 0
        var thrownError: Error?

        init(status: SMAppService.Status) {
            self.status = status
        }

        func register() throws {
            registerCalls += 1
            if let thrownError { throw thrownError }
            status = .enabled
        }

        func unregister() throws {
            unregisterCalls += 1
            if let thrownError { throw thrownError }
            status = .notRegistered
        }
    }

    func testIsEnabledReadsStatusAsSingleSourceOfTruth() {
        let enabled = MockLoginItem(status: .enabled)
        let notRegistered = MockLoginItem(status: .notRegistered)
        XCTAssertTrue(LaunchAtLoginController.isEnabled(using: enabled))
        XCTAssertFalse(LaunchAtLoginController.isEnabled(using: notRegistered))
    }

    func testSetEnabledRegistersAndUnregisters() {
        let item = MockLoginItem(status: .notRegistered)
        XCTAssertTrue(LaunchAtLoginController.setEnabled(true, using: item))
        XCTAssertEqual(item.registerCalls, 1)
        XCTAssertEqual(item.status, .enabled)

        XCTAssertTrue(LaunchAtLoginController.setEnabled(false, using: item))
        XCTAssertEqual(item.unregisterCalls, 1)
        XCTAssertEqual(item.status, .notRegistered)
    }

    func testSetEnabledReportsFailureWithoutChangingState() {
        let item = MockLoginItem(status: .notRegistered)
        item.thrownError = FakeError()

        XCTAssertFalse(LaunchAtLoginController.setEnabled(true, using: item))
        XCTAssertEqual(item.registerCalls, 1)
        XCTAssertEqual(item.status, .notRegistered)
    }
}
