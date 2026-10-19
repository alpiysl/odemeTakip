import Foundation
import Testing
@testable import OdemeTakip

struct NotificationContentBuilderTests {
    let nov2026 = YearMonth(year: 2026, month: 11)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        AppCalendar.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min)) ?? .distantPast
    }

    @Test func creditAndCashOnSeparateLines() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 36, monthly: 15_000, first: YearMonth(year: 2025, month: 9)),
            .credit(count: 16, monthly: 7_500, first: YearMonth(year: 2026, month: 2)),
            .cash(debt: 80_000, paid: 30_000, paymentCount: 4),
            .cash(.USD, debt: 3_000, paid: 600, paymentCount: 1),
        ]
        let content = NotificationContentBuilder.content(for: nov2026, payments: payments)
        #expect(content == NotificationContent(
            title: "Kasım ödemeleri",
            body: "Kredi: ₺22.500 (2 taksit)\nElden kalan: ₺50.000 + $2.400"))
    }

    @Test func creditOnlySkipsPaidInstallments() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 12, monthly: 1_000, first: nov2026),
            .credit(.USD, count: 12, monthly: 300, first: nov2026),
            .credit(count: 12, monthly: 5_000, first: nov2026, paid: [0]),
        ]
        let content = NotificationContentBuilder.content(for: nov2026, payments: payments)
        #expect(content?.body == "Kredi: ₺1.000 + $300 (2 taksit)")
    }

    @Test func cashOnly() {
        let content = NotificationContentBuilder.content(for: nov2026, payments: [.cash(debt: 50_000)])
        #expect(content?.body == "Elden kalan: ₺50.000")
    }

    @Test func nothingDueReturnsNil() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 1, monthly: 100, first: nov2026, paid: [0]),
            .cash(debt: 100, paid: 100, paymentCount: 1),
        ]
        #expect(NotificationContentBuilder.content(for: nov2026, payments: payments) == nil)
        #expect(NotificationContentBuilder.content(for: nov2026, payments: []) == nil)
    }

    @Test func triggerMonthsStartNextMonthMidMonth() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 10, 19, 15))
        #expect(months.count == 12)
        #expect(months.first == YearMonth(year: 2026, month: 11))
        #expect(months.last == YearMonth(year: 2027, month: 10))
    }

    @Test func triggerMonthsIncludeTodayBeforeNine() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 11, 1, 8, 30))
        #expect(months.first == YearMonth(year: 2026, month: 11))
    }

    @Test func triggerMonthsSkipTodayAfterNine() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 11, 1, 9, 30))
        #expect(months.first == YearMonth(year: 2026, month: 12))
    }

    @Test func triggerMonthsCrossYear() {
        let months = NotificationContentBuilder.triggerMonths(after: date(2026, 12, 15, 10), count: 2)
        #expect(months == [YearMonth(year: 2027, month: 1), YearMonth(year: 2027, month: 2)])
    }

    @Test func receivablesNeverAppearInNotification() {
        let payments: [PaymentSnapshot] = [
            PaymentSnapshot(kind: .receivable, currency: .TRY, totalDebt: 20_000),
        ]
        #expect(NotificationContentBuilder.content(for: nov2026, payments: payments) == nil)
    }

    @Test func goldDebtsConvertWhenPricesExist() {
        let payments: [PaymentSnapshot] = [.cash(.ceyrek, debt: 5), .cash(debt: 1_000)]
        let rates = ExchangeRates(usd: 40, eur: 50, bulletinDate: .now, fetchedAt: .now,
                                  gold: [Currency.ceyrek.rawValue: 10_000])
        #expect(NotificationContentBuilder.content(for: nov2026, payments: payments, rates: rates)?.body
                == "Elden kalan: ₺51.000")
        #expect(NotificationContentBuilder.content(for: nov2026, payments: payments, rates: nil)?.body
                == "Elden kalan: ₺1.000 + 5 çeyrek")
    }
}
