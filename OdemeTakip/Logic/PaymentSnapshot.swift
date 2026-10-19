import Foundation

/// SwiftData modelinin değer kopyası. Tüm hesaplar bunun üzerinde çalışır.
struct PaymentSnapshot: Identifiable, Equatable, Sendable {
    var id = UUID()
    var kind: PaymentKind
    var currency: Currency
    var installmentCount = 0
    var monthlyAmount: Decimal = 0
    var firstMonth = YearMonth(year: 2000, month: 1)
    var paidInstallments: Set<Int> = []
    var totalDebt: Decimal = 0
    var cashPaid: Decimal = 0
    var cashPaymentCount = 0

    static func credit(_ currency: Currency = .TRY, count: Int, monthly: Decimal,
                       first: YearMonth, paid: Set<Int> = []) -> PaymentSnapshot {
        PaymentSnapshot(kind: .credit, currency: currency, installmentCount: count,
                        monthlyAmount: monthly, firstMonth: first, paidInstallments: paid)
    }

    static func cash(_ currency: Currency = .TRY, debt: Decimal, paid: Decimal = 0,
                     paymentCount: Int = 0) -> PaymentSnapshot {
        PaymentSnapshot(kind: .cash, currency: currency, totalDebt: debt,
                        cashPaid: paid, cashPaymentCount: paymentCount)
    }
}
