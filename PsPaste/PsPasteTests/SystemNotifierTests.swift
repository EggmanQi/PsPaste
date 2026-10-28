import XCTest
@testable import PsPaste

@MainActor
final class SystemNotifierTests: XCTestCase {

    private func makeNotifier(
        grant: Bool
    ) -> (SystemNotifier, authRequests: () -> Int, deliveries: () -> [(title: String, body: String)]) {
        var authRequests = 0
        var deliveries: [(title: String, body: String)] = []
        let notifier = SystemNotifier(
            requestAuthorization: { completion in
                authRequests += 1
                completion(grant)
            },
            enqueue: { title, body in
                deliveries.append((title, body))
            }
        )
        return (notifier, { authRequests }, { deliveries })
    }

    func testDeniedAuthorizationDeliversNothing() {
        let (notifier, authRequests, deliveries) = makeNotifier(grant: false)

        notifier.deliver(title: "P's Paste", body: "conflict")
        XCTAssertEqual(deliveries().count, 0)
        XCTAssertEqual(authRequests(), 1)

        // Authorization is cached: no repeated system prompts.
        notifier.deliver(title: "P's Paste", body: "conflict again")
        XCTAssertEqual(deliveries().count, 0)
        XCTAssertEqual(authRequests(), 1)
    }

    func testGrantedAuthorizationDeliversImmediately() {
        let (notifier, authRequests, deliveries) = makeNotifier(grant: true)

        notifier.deliver(title: "P's Paste", body: "shortcut conflict")
        XCTAssertEqual(deliveries().count, 1)
        XCTAssertEqual(deliveries().first?.title, "P's Paste")
        XCTAssertEqual(deliveries().first?.body, "shortcut conflict")

        notifier.deliver(title: "T", body: "B")
        XCTAssertEqual(deliveries().count, 2)
        XCTAssertEqual(authRequests(), 1)
    }
}
