import Foundation
import SwiftData
import XCTest
@testable import PsPaste

/// Full-search predicate (Task 14-C): hits the copied text and the source
/// app name, case-insensitive, evaluated by SwiftData (not in memory).
@MainActor
final class ItemSearchTests: XCTestCase {

    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func insert(text: String?, appName: String?) {
        let item = ClipboardItem(
            sourceAppBundleID: nil,
            sourceAppName: appName,
            sourceDevice: "Test",
            contentTypes: ["public.utf8-plain-text"],
            text: text,
            contentHash: UUID().uuidString
        )
        let context = ModelContext(container)
        context.insert(item)
        try! context.save()
    }

    private func search(_ term: String) -> [ClipboardItem] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: ClipboardItem.searchPredicate(matching: term),
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try! context.fetch(descriptor)
    }

    func testMatchesCopiedText() {
        insert(text: "meeting notes for friday", appName: "Notes")
        XCTAssertEqual(search("friday").count, 1)
        XCTAssertTrue(search("saturday").isEmpty)
    }

    func testMatchesSourceAppName() {
        insert(text: "unrelated content", appName: "Google Chrome")
        XCTAssertEqual(search("chrome").count, 1)
        XCTAssertEqual(search("Google").count, 1)
    }

    func testMatchingIsCaseInsensitive() {
        insert(text: "The Quick Brown Fox", appName: nil)
        XCTAssertEqual(search("quick").count, 1)
        XCTAssertEqual(search("QUICK").count, 1)
    }

    func testMatchesTextOrAppNameInOnePredicate() {
        insert(text: "release checklist", appName: "Terminal")
        insert(text: "buy milk", appName: "Safari")
        XCTAssertEqual(search("terminal").count, 1)
        XCTAssertEqual(search("milk").count, 1)
        XCTAssertTrue(search("unmatched").isEmpty)
    }

    func testNilTextAndNameNeverMatch() {
        insert(text: nil, appName: nil)
        XCTAssertTrue(search("anything").isEmpty)
    }
}
