import Foundation

struct DueSummary: Equatable, Sendable {
    var amount: Decimal
    var count: Int
}

struct Totals: Equatable, Sendable {
    var credit: [Currency: Decimal]
    var cash: [Currency: Decimal]
    /// Sadece borçlar (kredi + elden).
    var overall: [Currency: Decimal]
    var receivable: [Currency: Decimal] = [:]
}

enum ThisMonthStatus: Equatable {
    case none
    case allPaid
    case due([Currency: DueSummary])
}

struct InstallmentRow: Identifiable, Equatable, Sendable {
    let index: Int
    let month: YearMonth
    let isPaid: Bool
    let isCurrent: Bool
    var id: Int { index }
}

struct CreditSchedule: Equatable {
    let allRows: [InstallmentRow]
    let collapsedPaidCount: Int
    var visibleRows: [InstallmentRow] { Array(allRows.dropFirst(collapsedPaidCount)) }
}

enum PaymentCalculator {
    static func paidCount(_ p: PaymentSnapshot) -> Int {
        switch p.kind {
        case .credit: p.paidInstallments.filter { $0 >= 0 && $0 < p.installmentCount }.count
        case .cash, .receivable: p.cashPaymentCount
        }
    }

    static func total(_ p: PaymentSnapshot) -> Decimal {
        switch p.kind {
        case .credit: Decimal(max(p.installmentCount, 0)) * p.monthlyAmount
        case .cash, .receivable: p.totalDebt
        }
    }

    static func paid(_ p: PaymentSnapshot) -> Decimal {
        switch p.kind {
        case .credit: Decimal(paidCount(p)) * p.monthlyAmount
        case .cash, .receivable: p.cashPaid
        }
    }

    static func remaining(_ p: PaymentSnapshot) -> Decimal {
        max(Decimal(0), total(p) - paid(p))
    }

    static func isCompleted(_ p: PaymentSnapshot) -> Bool { remaining(p) == 0 }

    static func installmentMonth(_ p: PaymentSnapshot, index: Int) -> YearMonth {
        p.firstMonth.adding(months: index)
    }

    static func lastInstallmentMonth(_ p: PaymentSnapshot) -> YearMonth? {
        p.installmentCount > 0 ? installmentMonth(p, index: p.installmentCount - 1) : nil
    }

    static func installmentIndex(_ p: PaymentSnapshot, in month: YearMonth) -> Int? {
        guard p.kind == .credit else { return nil }
        let index = month.months(from: p.firstMonth)
        return (0..<max(p.installmentCount, 0)).contains(index) ? index : nil
    }

    static func dueUnpaid(_ payments: [PaymentSnapshot], in month: YearMonth) -> [Currency: DueSummary] {
        var result: [Currency: DueSummary] = [:]
        for p in payments {
            guard let index = installmentIndex(p, in: month), !p.paidInstallments.contains(index) else { continue }
            var summary = result[p.currency] ?? DueSummary(amount: 0, count: 0)
            summary.amount += p.monthlyAmount
            summary.count += 1
            result[p.currency] = summary
        }
        return result
    }

    static func thisMonthStatus(_ payments: [PaymentSnapshot], in month: YearMonth) -> ThisMonthStatus {
        let hasInstallment = payments.contains { installmentIndex($0, in: month) != nil }
        guard hasInstallment else { return .none }
        let due = dueUnpaid(payments, in: month)
        return due.isEmpty ? .allPaid : .due(due)
    }

    static func totals(_ payments: [PaymentSnapshot]) -> Totals {
        var totals = Totals(credit: [:], cash: [:], overall: [:])
        for p in payments {
            let left = remaining(p)
            guard left > 0 else { continue }
            switch p.kind {
            case .credit: totals.credit[p.currency, default: 0] += left
            case .cash: totals.cash[p.currency, default: 0] += left
            case .receivable:
                totals.receivable[p.currency, default: 0] += left
                continue
            }
            totals.overall[p.currency, default: 0] += left
        }
        return totals
    }

    /// Kalanı olan kayıtlarda en sık kullanılan para birimi; eşitlikte TL, sonra USD, EUR.
    static func primaryCurrency(_ payments: [PaymentSnapshot]) -> Currency {
        var counts: [Currency: Int] = [:]
        for p in payments where p.kind != .receivable && remaining(p) > 0 {
            counts[p.currency, default: 0] += 1
        }
        return Currency.allCases.sorted { a, b in
            let ca = counts[a] ?? 0
            let cb = counts[b] ?? 0
            return ca != cb ? ca > cb : a < b
        }.first ?? .TRY
    }

    static func schedule(_ p: PaymentSnapshot, current: YearMonth) -> CreditSchedule {
        let rows = (0..<max(p.installmentCount, 0)).map { index in
            let month = installmentMonth(p, index: index)
            return InstallmentRow(index: index, month: month,
                                  isPaid: p.paidInstallments.contains(index),
                                  isCurrent: month == current)
        }
        var collapsed = 0
        for row in rows {
            guard row.isPaid, row.month < current else { break }
            collapsed += 1
        }
        return CreditSchedule(allRows: rows, collapsedPaidCount: collapsed)
    }
}
