import XCTest
@testable import PsPaste

/// Task 8-D: an image entry whose payload cannot be decoded must fall back to
/// its captured text instead of a permanent gray placeholder.
final class CardViewTests: XCTestCase {

    func testCorruptImageWithTextFallsBack() {
        XCTAssertTrue(
            CardView.shouldFallbackToText(isImage: true, hasText: true, imageLoadFailed: true)
        )
    }

    func testImageStillLoadingDoesNotFallBack() {
        XCTAssertFalse(
            CardView.shouldFallbackToText(isImage: true, hasText: true, imageLoadFailed: false)
        )
    }

    func testCorruptImageWithoutTextDoesNotFallBack() {
        XCTAssertFalse(
            CardView.shouldFallbackToText(isImage: true, hasText: false, imageLoadFailed: true)
        )
    }

    func testTextEntryNeverFallsBack() {
        XCTAssertFalse(
            CardView.shouldFallbackToText(isImage: false, hasText: true, imageLoadFailed: true)
        )
    }
}
