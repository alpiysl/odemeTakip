import Foundation
import Testing
@testable import OdemeTakip

@MainActor
struct MonthTrackerTests {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        AppCalendar.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    @Test func refreshMovesToNewMonth() {
        let tracker = MonthTracker(now: date(2026, 10, 31))
        #expect(tracker.current == YearMonth(year: 2026, month: 10))
        tracker.refresh(now: date(2026, 11, 1))
        #expect(tracker.current == YearMonth(year: 2026, month: 11))
    }

    @Test func refreshWithinSameMonthKeepsValue() {
        let tracker = MonthTracker(now: date(2026, 10, 1))
        tracker.refresh(now: date(2026, 10, 30))
        #expect(tracker.current == YearMonth(year: 2026, month: 10))
    }
}
