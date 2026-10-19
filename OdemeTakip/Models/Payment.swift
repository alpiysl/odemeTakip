import Foundation
import SwiftData

@Model
final class Payment {
    var id = UUID()
    var name = ""
    var icon = "🏦"
    var kindRaw = PaymentKind.credit.rawValue
    var currencyRaw = Currency.TRY.rawValue
    var createdAt = Date.now
    // Kredi
    var installmentCount = 0
    var monthlyAmount: Decimal = 0
    var firstYear = 2000
    var firstMonthNumber = 1
    var paidInstallmentIndexes: [Int] = []
    // Elden
    var totalDebt: Decimal = 0
    @Relationship(deleteRule: .cascade, inverse: \CashPayment.payment)
    var cashPayments: [CashPayment]? = []

    init(kind: PaymentKind) {
        self.kindRaw = kind.rawValue
    }

    var kind: PaymentKind {
        get { PaymentKind(rawValue: kindRaw) ?? .credit }
        set { kindRaw = newValue.rawValue }
    }

    var currency: Currency {
        get { Currency(rawValue: currencyRaw) ?? .TRY }
        set { currencyRaw = newValue.rawValue }
    }

    var firstMonth: YearMonth {
        get { YearMonth(year: firstYear, month: firstMonthNumber) }
        set {
            firstYear = newValue.year
            firstMonthNumber = newValue.month
        }
    }

    private var liveCashPayments: [CashPayment] {
        (cashPayments ?? []).filter { !$0.isDeleted }
    }

    var sortedCashPayments: [CashPayment] {
        liveCashPayments.sorted { $0.date > $1.date }
    }

    var snapshot: PaymentSnapshot {
        let entries = liveCashPayments
        return PaymentSnapshot(
            id: id, kind: kind, currency: currency,
            installmentCount: installmentCount, monthlyAmount: monthlyAmount,
            firstMonth: firstMonth, paidInstallments: Set(paidInstallmentIndexes),
            totalDebt: totalDebt,
            cashPaid: entries.reduce(Decimal(0)) { $0 + $1.amount },
            cashPaymentCount: entries.count)
    }

    static func make(from draft: PaymentDraft) -> Payment? {
        guard draft.isValid else { return nil }
        let payment = Payment(kind: draft.kind)
        return payment.apply(draft) ? payment : nil
    }

    @discardableResult
    func apply(_ draft: PaymentDraft) -> Bool {
        guard draft.isValid, draft.kind == kind else { return false }
        switch kind {
        case .credit:
            guard let count = draft.installmentCount, let monthly = draft.monthlyAmount,
                  let prepaid = draft.prepaidCount else { return false }
            installmentCount = count
            monthlyAmount = monthly
            firstMonth = draft.firstMonth
            if draft.isEditing {
                paidInstallmentIndexes = paidInstallmentIndexes.filter { $0 < count }
            } else {
                paidInstallmentIndexes = Array(0..<prepaid)
            }
        case .cash:
            guard let debt = draft.totalDebt else { return false }
            totalDebt = debt
        }
        name = draft.trimmedName
        icon = draft.icon
        currency = draft.currency
        return true
    }

    func makeDraft() -> PaymentDraft {
        var draft = PaymentDraft(firstMonth: firstMonth)
        draft.kind = kind
        draft.name = name
        draft.icon = icon
        draft.currency = currency
        draft.isEditing = true
        switch kind {
        case .credit:
            draft.installmentCountText = String(installmentCount)
            draft.monthlyAmountText = AmountParser.editingText(monthlyAmount)
            draft.minimumInstallmentCount = max(1, (paidInstallmentIndexes.max() ?? -1) + 1)
        case .cash:
            draft.totalDebtText = AmountParser.editingText(totalDebt)
            draft.minimumTotalDebt = snapshot.cashPaid
        }
        return draft
    }

    func toggleInstallment(_ index: Int) {
        guard kind == .credit, (0..<installmentCount).contains(index) else { return }
        if let position = paidInstallmentIndexes.firstIndex(of: index) {
            paidInstallmentIndexes.remove(at: position)
        } else {
            paidInstallmentIndexes.append(index)
            paidInstallmentIndexes.sort()
        }
    }

    func addCashPayment(amount: Decimal, date: Date) {
        let entry = CashPayment(amount: amount, date: date)
        modelContext?.insert(entry)
        entry.payment = self
    }

    func removeCashPayment(_ entry: CashPayment) {
        modelContext?.delete(entry)
    }
}
