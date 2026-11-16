import Foundation

/// Raporda yer alabilecek bölümler; kullanıcı oluşturmadan önce açıp kapatır.
enum ReportSection: String, CaseIterable, Identifiable, Sendable {
    case summary
    case schedule
    case history
    case receivables
    case savings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: L10n.Documents.sectionSummary
        case .schedule: L10n.Documents.sectionSchedule
        case .history: L10n.Documents.sectionHistory
        case .receivables: L10n.Documents.sectionReceivables
        case .savings: L10n.Documents.sectionSavings
        }
    }
}

struct ReportOptions: Equatable, Sendable {
    /// Seçili borç, alacak ve birikim kayıtları.
    var selectedIDs: Set<UUID>
    var sections: Set<ReportSection> = Set(ReportSection.allCases)
    /// Taksit ve ödeme satırları için ay aralığı; nil ise tümü.
    var range: ClosedRange<YearMonth>?

    var canGenerate: Bool { !selectedIDs.isEmpty && !sections.isEmpty }
}

struct ReportPaymentInput: Identifiable, Sendable {
    struct Entry: Sendable {
        var amount: Decimal
        var date: Date
    }

    var id: UUID
    var name: String
    var icon: String
    var snapshot: PaymentSnapshot
    var cashPayments: [Entry]
}

struct ReportAssetInput: Identifiable, Sendable {
    var id: UUID
    var name: String
    var icon: String
    var unit: Currency
    var quantity: Decimal
}

struct ReportLine: Equatable, Sendable {
    var label: String
    var value: String
}

struct ReportRow: Equatable, Sendable {
    var cells: [String]
    /// Ödenmiş satırlar PDF'te yeşil.
    var isPaid = false
}

struct ReportBlock: Equatable, Sendable {
    var title: String
    var subtitle: String
    var facts: [ReportLine]
    var columns: [String]
    var rows: [ReportRow]
}

struct ReportData: Equatable, Sendable {
    var title: String
    var generatedText: String
    var rangeText: String?
    var summary: [ReportLine]
    var debts: [ReportBlock]
    var receivables: [ReportBlock]
    var savings: [ReportLine]
}

enum ReportBuilder {
    static func build(payments: [ReportPaymentInput], assets: [ReportAssetInput],
                      options: ReportOptions, now: Date = .now,
                      calendar: Calendar = AppCalendar.calendar) -> ReportData {
        let selected = payments.filter { options.selectedIDs.contains($0.id) }
        let debts = selected.filter { $0.snapshot.kind != .receivable }
        let receivables = options.sections.contains(.receivables)
            ? selected.filter { $0.snapshot.kind == .receivable } : []
        let savings = options.sections.contains(.savings)
            ? assets.filter { options.selectedIDs.contains($0.id) } : []

        var summary: [ReportLine] = []
        if options.sections.contains(.summary) {
            if !debts.isEmpty {
                summary.append(ReportLine(label: L10n.Documents.remainingDebt,
                                          value: MoneyFormatter.joined(remainingByCurrency(debts))))
            }
            if !receivables.isEmpty {
                summary.append(ReportLine(label: L10n.Documents.remainingReceivableTotal,
                                          value: MoneyFormatter.joined(remainingByCurrency(receivables))))
            }
            summary.append(ReportLine(label: L10n.Documents.recordCount,
                                      value: String(debts.count + receivables.count + savings.count)))
        }

        // Aralık yalnız satırları süzer; satır gösteren bölüm kapalıysa alt başlıkta anlamsız.
        let showsRows = options.sections.contains(.schedule) || options.sections.contains(.history)
        let range = showsRows ? options.range : nil
        return ReportData(
            title: L10n.Documents.reportTitle,
            generatedText: L10n.Documents.generated(fullDate(now, calendar)),
            rangeText: range.map { L10n.Documents.range($0.lowerBound.longLabel, $0.upperBound.longLabel) },
            summary: summary,
            debts: debts.map { block($0, options: options, calendar: calendar) },
            receivables: receivables.map { block($0, options: options, calendar: calendar) },
            savings: savings.map {
                ReportLine(label: "\($0.icon) \($0.name)", value: MoneyFormatter.string($0.quantity, $0.unit))
            })
    }

    private static func remainingByCurrency(_ payments: [ReportPaymentInput]) -> [Currency: Decimal] {
        var result: [Currency: Decimal] = [:]
        for p in payments {
            result[p.snapshot.currency, default: 0] += PaymentCalculator.remaining(p.snapshot)
        }
        return result
    }

    private static func fullDate(_ date: Date, _ calendar: Calendar) -> String {
        L10n.Documents.fullDate(TurkishMonths.dayMonth(date, calendar: calendar), calendar.component(.year, from: date))
    }

    private static func block(_ p: ReportPaymentInput, options: ReportOptions, calendar: Calendar) -> ReportBlock {
        let s = p.snapshot
        let money = { (value: Decimal) in MoneyFormatter.string(value, s.currency) }
        let receivable = s.kind == .receivable
        let facts = [
            ReportLine(label: L10n.Documents.total, value: money(PaymentCalculator.total(s))),
            ReportLine(label: receivable ? L10n.Documents.collected : L10n.Documents.paid,
                       value: money(PaymentCalculator.paid(s))),
            ReportLine(label: L10n.Documents.remaining, value: money(PaymentCalculator.remaining(s))),
        ]
        let inRange = { (month: YearMonth) in options.range?.contains(month) ?? true }

        switch s.kind {
        case .credit:
            let rows = options.sections.contains(.schedule)
                ? (0..<max(s.installmentCount, 0)).compactMap { index -> ReportRow? in
                    let month = PaymentCalculator.installmentMonth(s, index: index)
                    guard inRange(month) else { return nil }
                    let paid = s.paidInstallments.contains(index)
                    return ReportRow(cells: [String(index + 1), month.longLabel, money(s.monthlyAmount),
                                             paid ? L10n.Documents.statusPaid : L10n.Documents.statusPending],
                                     isPaid: paid)
                }
                : []
            return ReportBlock(
                title: p.name,
                subtitle: L10n.Documents.creditSubtitle(s.kind.title, money(s.monthlyAmount), s.installmentCount),
                facts: facts,
                columns: [L10n.Documents.columnNumber, L10n.Documents.columnMonth,
                          L10n.Documents.columnAmount, L10n.Documents.columnStatus],
                rows: rows)
        case .cash, .receivable:
            let rows = options.sections.contains(.history)
                ? p.cashPayments
                    .filter { inRange(YearMonth(date: $0.date, calendar: calendar)) }
                    .sorted { $0.date > $1.date }
                    .map { ReportRow(cells: [fullDate($0.date, calendar), money($0.amount)], isPaid: true) }
                : []
            return ReportBlock(
                title: p.name,
                subtitle: s.kind.title,
                facts: facts,
                columns: [L10n.Documents.columnDate, L10n.Documents.columnAmount],
                rows: rows)
        }
    }
}

extension ReportPaymentInput {
    init(_ payment: Payment) {
        self.init(id: payment.id, name: payment.name, icon: payment.icon, snapshot: payment.snapshot,
                  cashPayments: payment.sortedCashPayments.map { Entry(amount: $0.amount, date: $0.date) })
    }
}

extension ReportAssetInput {
    init(_ asset: Asset) {
        self.init(id: asset.id, name: asset.name, icon: asset.icon, unit: asset.unit, quantity: asset.quantity)
    }
}
