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

    // MARK: - Task 10: static timestamps (UI.md §2.2)

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func utcDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = utc
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)!
    }

    func testTodayShowsHoursAndMinutesOnly() {
        let now = utcDate("2026-10-29 14:30")
        let copy = utcDate("2026-10-29 09:05")
        XCTAssertEqual(
            CardView.timeLabel(for: copy, now: now, calendar: utc),
            "09:05"
        )
    }

    func testEarlierDayShowsMonthDayAndTime() {
        let now = utcDate("2026-10-29 00:10")
        let copy = utcDate("2026-10-28 23:55")
        XCTAssertEqual(
            CardView.timeLabel(for: copy, now: now, calendar: utc),
            "10-28 23:55"
        )
    }

    func testCrossYearShowsMonthDayAndTime() {
        let now = utcDate("2026-01-01 08:00")
        let copy = utcDate("2025-12-31 18:20")
        XCTAssertEqual(
            CardView.timeLabel(for: copy, now: now, calendar: utc),
            "12-31 18:20"
        )
    }
}
