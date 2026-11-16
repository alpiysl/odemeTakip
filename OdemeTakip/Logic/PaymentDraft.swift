import Foundation

struct PaymentDraft: Equatable {
    static let maxInstallments = 480
    static let maxAmount: Decimal = 1_000_000_000_000
    /// Borç ve alacakta seçilebilen birimler: TL, döviz ve altın türleri.
    static let currencyOptions = Currency.allCases
    static let icons = ["🏦", "🏠", "🚗", "💳", "📱", "🎓", "🤝", "💵", "👤", "🛒", "🏥", "✈️"]

    static func defaultIcon(for kind: PaymentKind) -> String {
        switch kind {
        case .credit: "🏦"
        case .cash: "🤝"
        case .receivable: "💰"
        }
    }

    var kind: PaymentKind = .credit
    var name = ""
    var icon = PaymentDraft.defaultIcon(for: .credit)
    var currency: Currency = .TRY
    var installmentCountText = ""
    var monthlyAmountText = ""
    var firstMonth: YearMonth
    var prepaidCountText = ""
    var totalDebtText = ""
    var isEditing = false
    /// Düzenlemede: ödenmiş en büyük taksit no + 1.
    var minimumInstallmentCount = 1
    /// Düzenlemede: elden ödenen toplam.
    var minimumTotalDebt: Decimal = 0

    init(firstMonth: YearMonth) {
        self.firstMonth = firstMonth
    }

    var trimmedName: String { Self.trim(name) }

    var installmentCount: Int? {
        guard let value = Int(Self.trim(installmentCountText)),
              (1...Self.maxInstallments).contains(value),
              value >= minimumInstallmentCount else { return nil }
        return value
    }

    var monthlyAmount: Decimal? { Self.positiveAmount(monthlyAmountText) }

    var prepaidCount: Int? {
        if isEditing { return 0 }
        let text = Self.trim(prepaidCountText)
        if text.isEmpty { return 0 }
        guard let value = Int(text), value >= 0, let count = installmentCount, value <= count else { return nil }
        return value
    }

    var totalDebt: Decimal? {
        guard let value = Self.positiveAmount(totalDebtText), value >= minimumTotalDebt else { return nil }
        return value
    }

    var validationMessage: String? {
        if trimmedName.isEmpty { return L10n.Validation.nameRequired }
        switch kind {
        case .credit:
            guard let count = Int(Self.trim(installmentCountText)),
                  (1...Self.maxInstallments).contains(count) else {
                return L10n.Validation.installmentRange(Self.maxInstallments)
            }
            if count < minimumInstallmentCount {
                return L10n.Validation.installmentBelowPaid(minimumInstallmentCount)
            }
            if monthlyAmount == nil { return L10n.Validation.invalidMonthlyAmount }
            if prepaidCount == nil { return L10n.Validation.prepaidRange(count) }
        case .cash:
            guard let debt = Self.positiveAmount(totalDebtText) else { return L10n.Validation.invalidTotalDebt }
            if debt < minimumTotalDebt {
                return L10n.Validation.totalDebtBelowPaid(MoneyFormatter.string(minimumTotalDebt, currency))
            }
        case .receivable:
            guard let total = Self.positiveAmount(totalDebtText) else { return L10n.Validation.invalidTotalReceivable }
            if total < minimumTotalDebt {
                return L10n.Validation.totalReceivableBelowCollected(MoneyFormatter.string(minimumTotalDebt, currency))
            }
        }
        return nil
    }

    var isValid: Bool { validationMessage == nil }

    /// Ekranda gösterilecek mesaj; kullanıcı ondalık yazarken ("1500,") susar.
    var visibleValidationMessage: String? {
        let amounts = kind == .credit ? [monthlyAmountText] : [totalDebtText]
        if amounts.contains(where: AmountParser.isIncomplete) { return nil }
        return validationMessage
    }

    var hasInput: Bool {
        ![name, installmentCountText, monthlyAmountText, totalDebtText].allSatisfy { Self.trim($0).isEmpty }
    }

    /// Yeni kredi formu için canlı özet.
    var preview: PaymentSnapshot? {
        guard !isEditing, isValid, kind == .credit,
              let count = installmentCount, let monthly = monthlyAmount, let prepaid = prepaidCount else { return nil }
        return .credit(currency, count: count, monthly: monthly, first: firstMonth, paid: Set(0..<prepaid))
    }

    private static func positiveAmount(_ text: String) -> Decimal? {
        guard let value = AmountParser.parse(text), value > 0, value <= maxAmount else { return nil }
        return value
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
