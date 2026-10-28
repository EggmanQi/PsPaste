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
        var currentDate = start
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
        guard case .failed(let error) = states[0] else {
            return XCTFail("expected .failed, got \(states[0])")
        }
        XCTAssertFalse(error.isEmpty)
        XCTAssertNotNil(service.lastError)

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
        XCTAssertNil(service.lastError)
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
}
