import Carbon
import XCTest
@testable import PsPaste

@MainActor
final class HotKeyServiceTests: XCTestCase {

    private func makeService(
        results: [Bool],
        interval: TimeInterval = 30,
        start: Date = Date(timeIntervalSince1970: 1_000)
    ) -> (HotKeyService, current: () -> Date, calls: () -> Int) {
        var scripted = results
        var callCount = 0
        let currentDate = start
        let service = HotKeyService(
            now: { currentDate },
            retryInterval: interval,
            registerWithCarbon: { _, _ in
                callCount += 1
                return scripted.isEmpty ? false : scripted.removeFirst()
            }
        )
        return (service, { currentDate }, { callCount })
    }

    func testFailureExposesStateAndRetrySucceedsAfterInterval() {
        let (service, _, calls) = makeService(results: [false, true])
        var states: [HotKeyService.RegistrationState] = []
        service.onRegistrationStateChange = { states.append($0) }

        XCTAssertFalse(service.start())
        XCTAssertEqual(calls(), 1)
        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states[0], .failed(.default))

        // Immediate retry is gated by the interval: no second attempt yet.
        service.retryIfNeeded()
        XCTAssertEqual(calls(), 1)

        let start = Date(timeIntervalSince1970: 1_000)
        service.retryIfNeeded(now: start.addingTimeInterval(29))
        XCTAssertEqual(calls(), 1)
        service.retryIfNeeded(now: start.addingTimeInterval(30))
        XCTAssertEqual(calls(), 2)
        XCTAssertEqual(states.count, 2)
        XCTAssertEqual(states[1], .registered)
    }

    func testRepeatedFailureKeepsRetrying() {
        let start = Date(timeIntervalSince1970: 1_000)
        var current = start
        var scripted = [false, false, true]
        var callCount = 0
        let service = HotKeyService(
            now: { current },
            retryInterval: 30,
            registerWithCarbon: { _, _ in
                callCount += 1
                return scripted.removeFirst()
            }
        )
        var states: [HotKeyService.RegistrationState] = []
        service.onRegistrationStateChange = { states.append($0) }

        XCTAssertFalse(service.start())
        current = start.addingTimeInterval(30)
        service.retryIfNeeded()
        XCTAssertEqual(callCount, 2)
        guard case .failed = states[1] else {
            return XCTFail("expected second .failed, got \(states[1])")
        }

        current = start.addingTimeInterval(60)
        service.retryIfNeeded()
        XCTAssertEqual(callCount, 3)
        XCTAssertEqual(states[2], .registered)
    }

    func testNoRetryWithoutFailure() {
        let (service, _, calls) = makeService(results: [true])
        XCTAssertTrue(service.start())
        service.retryIfNeeded()
        XCTAssertEqual(calls(), 1)
    }

    func testShouldRetryBoundary() {
        let failure = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(
            HotKeyService.shouldRetry(
                lastFailureAt: failure,
                now: failure.addingTimeInterval(29.9),
                interval: 30
            )
        )
        XCTAssertTrue(
            HotKeyService.shouldRetry(
                lastFailureAt: failure,
                now: failure.addingTimeInterval(30),
                interval: 30
            )
        )
    }

    // MARK: - Task 15: runtime rebind + recorder modifier mapping

    func testRebindSuccessRegistersNewBinding() {
        var attempts: [(UInt32, UInt32)] = []
        let service = HotKeyService(
            registerWithCarbon: { keyCode, modifiers in
                attempts.append((keyCode, modifiers))
                return true
            }
        )
        _ = service.start()

        let next = HotKeyBinding(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey))
        XCTAssertTrue(service.rebind(to: next))
        XCTAssertEqual(attempts.last?.0, next.keyCode)
        XCTAssertEqual(attempts.last?.1, next.modifiers)
    }

    func testRebindFailureRestoresPreviousBinding() {
        var attempts: [(UInt32, UInt32)] = []
        var scripted = [true, false, true]
        let service = HotKeyService(
            registerWithCarbon: { keyCode, modifiers in
                attempts.append((keyCode, modifiers))
                return scripted.removeFirst()
            }
        )
        var states: [HotKeyService.RegistrationState] = []
        service.onRegistrationStateChange = { states.append($0) }
        _ = service.start()

        let next = HotKeyBinding(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey))
        XCTAssertFalse(service.rebind(to: next))

        // Attempt consumed the old binding before failing; the restore call
        // must re-register the previous one so the app is never hotkey-less.
        XCTAssertEqual(attempts.count, 3)
        XCTAssertEqual(attempts[2].0, HotKeyService.defaultKeyCode)
        XCTAssertEqual(attempts[2].1, HotKeyService.defaultModifiers)
        // The rejected candidate is reported to the caller only, never as a
        // registration failure (no notification for a key the user just tried).
        XCTAssertEqual(states, [.registered, .registered])
    }

    func testRebindFailureWhileConflictedReportsActiveBinding() {
        var scripted = [false, false, false]
        let service = HotKeyService(registerWithCarbon: { _, _ in scripted.removeFirst() })
        var states: [HotKeyService.RegistrationState] = []
        service.onRegistrationStateChange = { states.append($0) }
        _ = service.start()

        let next = HotKeyBinding(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey))
        XCTAssertFalse(service.rebind(to: next))

        XCTAssertEqual(states, [.failed(.default), .failed(.default)])
    }

    func testRebindSuccessAfterConflictStopsRetrying() {
        let start = Date(timeIntervalSince1970: 1_000)
        var callCount = 0
        var scripted = [false, true]
        let service = HotKeyService(
            now: { start },
            registerWithCarbon: { _, _ in
                callCount += 1
                return scripted.isEmpty ? true : scripted.removeFirst()
            }
        )
        _ = service.start()

        let next = HotKeyBinding(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey))
        XCTAssertTrue(service.rebind(to: next))
        service.retryIfNeeded(now: start.addingTimeInterval(60))

        XCTAssertEqual(callCount, 2)
    }

    func testCarbonModifiersMapsCocoaFlagsToCarbonMask() {
        XCTAssertEqual(
            HotKeyService.carbonModifiers(from: [.command, .shift]),
            UInt32(cmdKey | shiftKey)
        )
        XCTAssertEqual(
            HotKeyService.carbonModifiers(from: [.control, .option]),
            UInt32(controlKey | optionKey)
        )
        XCTAssertEqual(HotKeyService.carbonModifiers(from: []), 0)
    }

    func testModifierFlagsRoundTripsCarbonMask() {
        let all: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        XCTAssertEqual(
            HotKeyService.modifierFlags(fromCarbon: HotKeyService.carbonModifiers(from: all)),
            all
        )
        XCTAssertEqual(
            HotKeyService.modifierFlags(fromCarbon: HotKeyService.defaultModifiers),
            [.command, .shift]
        )
        XCTAssertEqual(HotKeyService.modifierFlags(fromCarbon: 0), [])
    }
}
