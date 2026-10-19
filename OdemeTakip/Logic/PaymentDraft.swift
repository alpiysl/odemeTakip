import Foundation

struct PaymentDraft: Equatable {
    static let maxInstallments = 480
    static let maxAmount: Decimal = 1_000_000_000_000
    static let icons = ["🏦", "🏠", "🚗", "💳", "📱", "🎓", "🤝", "💵", "👤", "🛒", "🏥", "✈️"]

    static func defaultIcon(for kind: PaymentKind) -> String {
        kind == .credit ? "🏦" : "🤝"
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
        if trimmedName.isEmpty { return "Ad gerekli" }
        switch kind {
        case .credit:
            guard let count = Int(Self.trim(installmentCountText)),
                  (1...Self.maxInstallments).contains(count) else {
                return "Taksit sayısı 1–\(Self.maxInstallments) arası olmalı"
            }
            if count < minimumInstallmentCount {
                return "Taksit sayısı ödenmiş taksitlerden (\(minimumInstallmentCount)) az olamaz"
            }
            if monthlyAmount == nil { return "Geçerli bir aylık tutar gir" }
            if prepaidCount == nil { return "Önceden ödenen taksit 0–\(count) arası olmalı" }
        case .cash:
            guard let debt = Self.positiveAmount(totalDebtText) else { return "Geçerli bir toplam borç gir" }
            if debt < minimumTotalDebt {
                return "Toplam borç ödenen tutardan (\(MoneyFormatter.string(minimumTotalDebt, currency))) az olamaz"
            }
        }
        return nil
    }

    var isValid: Bool { validationMessage == nil }

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
