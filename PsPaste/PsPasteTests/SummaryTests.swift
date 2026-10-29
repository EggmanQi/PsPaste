import XCTest
@testable import PsPaste

/// Task 10: middle truncation of long card text (UI.md §2.2) — at most 300
/// characters, keeping the first 70% and the last 30% with an ellipsis between.
final class SummaryTests: XCTestCase {

    func testShortTextIsReturnedInFull() {
        let text = "Just a short copy."
        XCTAssertEqual(ClipboardItem.middleTruncated(text), text)
    }

    func testTextAtBudgetIsReturnedInFull() {
        let text = String(repeating: "a", count: 300)
        XCTAssertEqual(ClipboardItem.middleTruncated(text), text)
    }

    func testTextBeyondBudgetKeepsHeadAndTail() {
        let head = String(repeating: "a", count: 210)
        let tail = String(repeating: "z", count: 90)
        let result = ClipboardItem.middleTruncated(head + "MIDDLE" + tail)
        XCTAssertEqual(
            result,
            "\(head) … \(tail)"
        )
        // Head + separator + tail stays within the budget plus the ellipsis.
        XCTAssertEqual(result.replacingOccurrences(of: " … ", with: "").count, 300)
    }

    func testBudgetIsConfigurable() {
        let result = ClipboardItem.middleTruncated(String(repeating: "x", count: 11), budget: 10)
        XCTAssertEqual(result, "xxxxxxx … xxx")
    }

    func testMultilineTextSurvivesWithinBudget() {
        let text = (1...10).map { "line \($0)" }.joined(separator: "\n")
        XCTAssertEqual(ClipboardItem.middleTruncated(text), text)
    }
}
