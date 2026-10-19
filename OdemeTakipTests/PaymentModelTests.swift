import Foundation
import SwiftData
import Testing
@testable import OdemeTakip

@MainActor
struct PaymentModelTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(for: Payment.self, CashPayment.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
    }

    private func creditDraft() -> PaymentDraft {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 2))
        d.kind = .credit
        d.name = "Araç"
        d.icon = "🚗"
        d.installmentCountText = "16"
        d.monthlyAmountText = "7.500"
        d.prepaidCountText = "8"
        return d
    }

    private func cashPayment(debt: String = "80000") throws -> Payment {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .cash
        d.name = "Ahmet"
        d.totalDebtText = debt
        let p = try #require(Payment.make(from: d))
        context.insert(p)
        return p
    }

    @Test func creditFromDraftMarksPrepaid() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        try context.save()
        #expect(p.kind == .credit)
        #expect(p.firstMonth == YearMonth(year: 2026, month: 2))
        #expect(p.paidInstallmentIndexes == Array(0..<8))
        #expect(PaymentCalculator.remaining(p.snapshot) == 60_000)
    }

    @Test func invalidDraftMakesNothing() {
        var d = creditDraft()
        d.name = ""
        #expect(Payment.make(from: d) == nil)
    }

    @Test func toggleInstallment() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        p.toggleInstallment(8)
        #expect(p.paidInstallmentIndexes.contains(8))
        p.toggleInstallment(8)
        #expect(!p.paidInstallmentIndexes.contains(8))
        p.toggleInstallment(99)
        #expect(!p.paidInstallmentIndexes.contains(99))
    }

    @Test func editDraftCarriesMinimums() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        let d = p.makeDraft()
        #expect(d.isEditing)
        #expect(d.minimumInstallmentCount == 8)
        #expect(d.monthlyAmountText == "7500")
        #expect(d.installmentCountText == "16")
        #expect(d.isValid)
    }

    @Test func applyEditKeepsPaidInstallments() throws {
        let p = try #require(Payment.make(from: creditDraft()))
        context.insert(p)
        var d = p.makeDraft()
        d.installmentCountText = "10"
        d.monthlyAmountText = "8000"
        #expect(p.apply(d))
        #expect(p.installmentCount == 10)
        #expect(p.monthlyAmount == 8_000)
        #expect(p.paidInstallmentIndexes == Array(0..<8))
    }

    @Test func cashPaymentsAddAndRemove() throws {
        let p = try cashPayment()
        p.addCashPayment(amount: 10_000, date: .now)
        p.addCashPayment(amount: 20_000, date: .now.addingTimeInterval(-86_400))
        try context.save()
        #expect(p.snapshot.cashPaid == 30_000)
        #expect(p.snapshot.cashPaymentCount == 2)
        #expect(p.sortedCashPayments.first?.amount == 10_000)

        let first = try #require(p.sortedCashPayments.first)
        p.removeCashPayment(first)
        try context.save()
        #expect(p.snapshot.cashPaid == 20_000)
        #expect(p.makeDraft().minimumTotalDebt == 20_000)
    }

    @Test func deletingPaymentCascades() throws {
        let p = try cashPayment()
        p.addCashPayment(amount: 5_000, date: .now)
        try context.save()
        context.delete(p)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<CashPayment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Payment>()) == 0)
    }
}
