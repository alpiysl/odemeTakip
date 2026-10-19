import Foundation
import Testing
@testable import OdemeTakip

struct YearMonthTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        AppCalendar.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .distantPast
    }

    @Test func normalizesOverflowingMonths() {
        #expect(YearMonth(year: 2026, month: 13) == YearMonth(year: 2027, month: 1))
        #expect(YearMonth(year: 2026, month: 0) == YearMonth(year: 2025, month: 12))
    }

    @Test func addingMonthsCrossesYearBoundary() {
        let nov = YearMonth(year: 2026, month: 11)
        #expect(nov.adding(months: 2) == YearMonth(year: 2027, month: 1))
        #expect(nov.adding(months: -11) == YearMonth(year: 2025, month: 12))
    }

    @Test func monthsBetween() {
        let a = YearMonth(year: 2025, month: 9)
        let b = YearMonth(year: 2026, month: 10)
        #expect(b.months(from: a) == 13)
        #expect(a.months(from: b) == -13)
    }

    @Test func comparesChronologically() {
        #expect(YearMonth(year: 2025, month: 12) < YearMonth(year: 2026, month: 1))
        #expect(!(YearMonth(year: 2026, month: 2) < YearMonth(year: 2026, month: 1)))
    }

    @Test func initFromDate() {
        #expect(YearMonth(date: date(2026, 10, 19)) == YearMonth(year: 2026, month: 10))
    }

    @Test func turkishLabels() {
        #expect(YearMonth(year: 2026, month: 10).longLabel == "Ekim 2026")
        #expect(YearMonth(year: 2025, month: 9).shortLabel == "Eyl 2025")
        #expect(YearMonth(year: 2026, month: 11).name == "Kasım")
        #expect(TurkishMonths.dayMonth(date(2026, 10, 5)) == "5 Eki")
    }

    @Test func firstDayIsFirstOfMonth() {
        let first = YearMonth(year: 2026, month: 2).firstDay(calendar: AppCalendar.calendar)
        let comps = AppCalendar.calendar.dateComponents([.year, .month, .day], from: first)
        #expect(comps.year == 2026 && comps.month == 2 && comps.day == 1)
    }

    @Test func currencyOrderAndSymbols() {
        #expect(Currency.allCases.sorted() == [.TRY, .USD, .EUR])
        #expect(Currency.TRY.symbol == "₺")
        #expect(Currency.USD.symbol == "$")
        #expect(Currency.EUR.symbol == "€")
        #expect(PaymentKind.credit.title == "Kredi")
        #expect(PaymentKind.cash.title == "Elden")
    }
}
