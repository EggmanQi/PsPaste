import Foundation
import SwiftData
import XCTest
@testable import PsPaste

@MainActor
final class ClipboardStoreTests: XCTestCase {

    private var payloadsRoot: URL!
    private var store: ClipboardStore!

    override func setUp() {
        super.setUp()
        let container = try! ModelContainer(
            for: ClipboardItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        payloadsRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = ClipboardStore(modelContainer: container, payloadsRoot: payloadsRoot)
    }

    private func snapshot(
        text: String?,
        payloads: [(type: String, data: Data)] = []
    ) -> ClipboardSnapshot {
        ClipboardSnapshot(
            contentTypes: ["public.utf8-plain-text"],
            text: text,
            payloads: payloads,
            contentHash: UUID().uuidString,
            sourceAppBundleID: nil
        )
    }

    private func imageData() -> Data {
        // Opaque bytes stand in for a real image; storage never inspects them.
        Data((0..<4096).map { UInt8($0 % 251) })
    }

    private func allItems(in container: ModelContainer) -> [ClipboardItem] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func testHistoryLimitPrunesOldestUnpinnedAndRemovesPayloads() throws {
        let container = store.modelContainer

        // A: oldest, unpinned, has payload. B: gets pinned. C: newest.
        store.save(snapshot(text: "a", payloads: [("public.png", imageData())]))
        store.save(snapshot(text: "b"))
        store.save(snapshot(text: "c"))

        // Pin B through a second context, as the Pinboard UI would.
        let pinningContext = ModelContext(container)
        let descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.text == "b" })
        let b = try XCTUnwrap(try pinningContext.fetch(descriptor).first)
        b.isPinned = true
        try pinningContext.save()

        store.historyLimit = 2
        store.save(snapshot(text: "trigger prune"))

        // Oldest-first pruning with excess 2 deletes a and c; pinned b and the
        // newest record survive.
        let remaining = allItems(in: container)
        XCTAssertEqual(remaining.map(\.text), ["b", "trigger prune"])
        XCTAssertTrue(remaining.first { $0.text == "b" }?.isPinned == true)
    }

    func testPrunedItemPayloadDirectoryIsDeleted() throws {
        store.save(snapshot(text: "with payload", payloads: [("public.png", imageData())]))
        let prunedID = try XCTUnwrap(payloadDirectoryName(forText: "with payload"))

        store.historyLimit = 1
        store.save(snapshot(text: "newer"))
        store.save(snapshot(text: "newest"))

        let directory = payloadsRoot.appendingPathComponent(prunedID, isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testPayloadIsStoredOnlyAsPathOnDisk() throws {
        let data = imageData()
        store.save(snapshot(text: nil, payloads: [("public.png", data)]))

        let item = try XCTUnwrap(allItems(in: store.modelContainer).first)
        XCTAssertNil(item.text)
        XCTAssertNotNil(item.payloadPath)

        let directory = payloadsRoot.appendingPathComponent(try XCTUnwrap(item.payloadPath), isDirectory: true)
        let file = directory.appendingPathComponent("0_public.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    func testPayloadContentsRoundTrip() throws {
        let png = imageData()
        store.save(snapshot(text: nil, payloads: [("public.png", png), ("public.tiff", png)]))

        let item = try XCTUnwrap(allItems(in: store.modelContainer).first)
        let payloads = store.payloadContents(for: item)
        XCTAssertEqual(payloads.map(\.type), ["public.png", "public.tiff"])
        XCTAssertEqual(payloads.map(\.data), [png, png])
        XCTAssertNotNil(store.imagePayload(for: item))
    }

    func testContainsNewestMatchingHash() {
        let snapshot = snapshot(text: "dedup me")
        XCTAssertFalse(store.containsNewest(matchingHash: snapshot.contentHash))

        store.save(snapshot)
        XCTAssertTrue(store.containsNewest(matchingHash: snapshot.contentHash))
        XCTAssertFalse(store.containsNewest(matchingHash: "other-hash"))
    }

    private func payloadDirectoryName(forText text: String) throws -> String? {
        let item = allItems(in: store.modelContainer).first { $0.text == text }
        return item?.payloadPath
    }
}
