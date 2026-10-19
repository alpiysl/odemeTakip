import Foundation
import Testing
@testable import OdemeTakip

struct PaymentCalculatorTests {
    let sep2025 = YearMonth(year: 2025, month: 9)
    let oct2026 = YearMonth(year: 2026, month: 10)

    @Test func creditTotals() {
        let p = PaymentSnapshot.credit(count: 36, monthly: 15_000, first: sep2025, paid: Set(0..<13))
        #expect(PaymentCalculator.total(p) == 540_000)
        #expect(PaymentCalculator.paidCount(p) == 13)
        #expect(PaymentCalculator.paid(p) == 195_000)
        #expect(PaymentCalculator.remaining(p) == 345_000)
        #expect(!PaymentCalculator.isCompleted(p))
    }

    @Test func outOfRangePaidIndexesAreIgnored() {
        let p = PaymentSnapshot.credit(count: 3, monthly: 100, first: sep2025, paid: [0, 5, -1])
        #expect(PaymentCalculator.paidCount(p) == 1)
        #expect(PaymentCalculator.remaining(p) == 200)
    }

    @Test func cashRemainingNeverNegative() {
        #expect(PaymentCalculator.remaining(.cash(debt: 80_000, paid: 30_000, paymentCount: 4)) == 50_000)
        #expect(PaymentCalculator.remaining(.cash(debt: 100, paid: 150, paymentCount: 1)) == 0)
        #expect(PaymentCalculator.isCompleted(.cash(debt: 100, paid: 100, paymentCount: 1)))
    }

    @Test func installmentMonthsCrossYearBoundary() {
        let p = PaymentSnapshot.credit(count: 4, monthly: 10, first: YearMonth(year: 2026, month: 11))
        #expect(PaymentCalculator.installmentMonth(p, index: 2) == YearMonth(year: 2027, month: 1))
        #expect(PaymentCalculator.lastInstallmentMonth(p) == YearMonth(year: 2027, month: 2))
        #expect(PaymentCalculator.installmentIndex(p, in: YearMonth(year: 2027, month: 1)) == 2)
        #expect(PaymentCalculator.installmentIndex(p, in: YearMonth(year: 2026, month: 10)) == nil)
        #expect(PaymentCalculator.installmentIndex(p, in: YearMonth(year: 2027, month: 3)) == nil)
    }

    @Test func dueUnpaidGroupsByCurrencyAndSkipsPaid() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 36, monthly: 15_000, first: sep2025),                       // Ekim 2026 = index 13, ödenmedi
            .credit(count: 16, monthly: 7_500, first: YearMonth(year: 2026, month: 2)), // index 8, ödenmedi
            .credit(.USD, count: 10, monthly: 300, first: oct2026, paid: [0]),          // ödendi
            .credit(.USD, count: 2, monthly: 999, first: YearMonth(year: 2024, month: 1)), // bitti
            .cash(debt: 50_000),
        ]
        let due = PaymentCalculator.dueUnpaid(payments, in: oct2026)
        #expect(due == [.TRY: DueSummary(amount: 22_500, count: 2)])
    }

    @Test func thisMonthStatusStates() {
        #expect(PaymentCalculator.thisMonthStatus([.cash(debt: 10)], in: oct2026) == .none)
        let paid = PaymentSnapshot.credit(count: 2, monthly: 100, first: oct2026, paid: [0])
        #expect(PaymentCalculator.thisMonthStatus([paid], in: oct2026) == .allPaid)
        let unpaid = PaymentSnapshot.credit(count: 2, monthly: 100, first: oct2026)
        #expect(PaymentCalculator.thisMonthStatus([unpaid], in: oct2026) == .due([.TRY: DueSummary(amount: 100, count: 1)]))
    }

    @Test func totalsNeverMixCurrencies() {
        let payments: [PaymentSnapshot] = [
            .credit(count: 10, monthly: 1_000, first: oct2026),
            .credit(.USD, count: 2, monthly: 50, first: oct2026),
            .cash(debt: 5_000, paid: 1_000, paymentCount: 1),
            .cash(.USD, debt: 2_400),
            .cash(.EUR, debt: 100, paid: 100, paymentCount: 1), // tamamlandı → yok
        ]
        let t = PaymentCalculator.totals(payments)
        #expect(t.credit == [.TRY: 10_000, .USD: 100])
        #expect(t.cash == [.TRY: 4_000, .USD: 2_400])
        #expect(t.overall == [.TRY: 14_000, .USD: 2_500])
    }

    @Test func primaryCurrencyRules() {
        #expect(PaymentCalculator.primaryCurrency([]) == .TRY)
        #expect(PaymentCalculator.primaryCurrency([.cash(.USD, debt: 1), .cash(.USD, debt: 1), .cash(debt: 1)]) == .USD)
        #expect(PaymentCalculator.primaryCurrency([.cash(.USD, debt: 1), .cash(debt: 1)]) == .TRY)
        #expect(PaymentCalculator.primaryCurrency([.cash(.EUR, debt: 1), .cash(.USD, debt: 1)]) == .USD)
        #expect(PaymentCalculator.primaryCurrency([.cash(.USD, debt: 1, paid: 1, paymentCount: 1), .cash(.EUR, debt: 5)]) == .EUR)
    }

    @Test func scheduleCollapsesLeadingPaidPastMonths() {
        let p = PaymentSnapshot.credit(count: 36, monthly: 15_000, first: sep2025, paid: Set(0..<13))
        let s = PaymentCalculator.schedule(p, current: oct2026)
        #expect(s.allRows.count == 36)
        #expect(s.collapsedPaidCount == 13)          // Eyl 2025 – Eyl 2026
        #expect(s.visibleRows.first?.month == oct2026)
        #expect(s.visibleRows.first?.isPaid == false)
        #expect(s.allRows[13].isCurrent)
        #expect(!s.allRows[12].isCurrent)
    }

    @Test func overduePastMonthStopsCollapse() {
        let p = PaymentSnapshot.credit(count: 6, monthly: 10, first: YearMonth(year: 2026, month: 5), paid: [0, 2])
        let s = PaymentCalculator.schedule(p, current: oct2026)
        #expect(s.collapsedPaidCount == 1)
        #expect(s.visibleRows.first?.index == 1)
    }

    @Test func receivablesStayOutOfDebtTotals() {
        let payments: [PaymentSnapshot] = [
            .cash(debt: 5_000),
            PaymentSnapshot(kind: .receivable, currency: .TRY, totalDebt: 20_000, cashPaid: 5_000, cashPaymentCount: 1),
            PaymentSnapshot(kind: .receivable, currency: .ceyrek, totalDebt: 4),
            PaymentSnapshot(kind: .receivable, currency: .USD, totalDebt: 10),
            PaymentSnapshot(kind: .receivable, currency: .USD, totalDebt: 10),
        ]
        let t = PaymentCalculator.totals(payments)
        #expect(t.cash == [.TRY: 5_000])
        #expect(t.overall == [.TRY: 5_000])
        #expect(t.receivable == [.TRY: 15_000, .ceyrek: 4, .USD: 20])
        #expect(PaymentCalculator.remaining(payments[1]) == 15_000)
        #expect(PaymentCalculator.primaryCurrency(payments) == .TRY)
    }
}
