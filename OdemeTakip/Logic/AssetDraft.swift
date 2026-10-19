import Foundation

/// Birikim kaleminin değer kopyası.
struct AssetSnapshot: Identifiable, Equatable, Sendable {
    var id: UUID
    var unit: Currency
    var quantity: Decimal
}

struct AssetDraft: Equatable {
    static let icons = ["🪙", "💵", "💶", "🏦", "💰", "📈", "🐷", "🏠"]

    static func defaultIcon(for unit: Currency) -> String {
        switch unit {
        case .TRY: "🏦"
        case .USD: "💵"
        case .EUR: "💶"
        case .gram, .ceyrek, .yarim, .tam, .resat: "🪙"
        }
    }

    var name = ""
    var icon = AssetDraft.defaultIcon(for: .TRY)
    var unit: Currency = .TRY
    /// Yeni kayıtta başlangıç miktarı (zorunlu); düzenlemede kullanılmaz.
    var amountText = ""
    var isEditing = false

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var amount: Decimal? {
        guard let value = AmountParser.parse(amountText), value > 0, value <= PaymentDraft.maxAmount else { return nil }
        return value
    }

    var validationMessage: String? {
        if trimmedName.isEmpty { return "Ad gerekli" }
        if !isEditing && amount == nil { return "Geçerli bir miktar gir" }
        return nil
    }

    var visibleValidationMessage: String? {
        AmountParser.isIncomplete(amountText) ? nil : validationMessage
    }

    var isValid: Bool { validationMessage == nil }
}

/// Birikime ekleme / çıkarma.
struct MovementDraft: Equatable {
    var amountText = ""
    var date = Date.now
    let available: Decimal
    let unit: Currency
    let isWithdrawal: Bool

    init(available: Decimal, unit: Currency, isWithdrawal: Bool) {
        self.available = available
        self.unit = unit
        self.isWithdrawal = isWithdrawal
    }

    var amount: Decimal? {
        guard let value = AmountParser.parse(amountText), value > 0, value <= PaymentDraft.maxAmount else { return nil }
        if isWithdrawal && value > available { return nil }
        return value
    }

    /// Hareket olarak kaydedilecek işaretli miktar.
    var signedAmount: Decimal? {
        amount.map { isWithdrawal ? -$0 : $0 }
    }

    var validationMessage: String? {
        let text = amountText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty || AmountParser.isIncomplete(text) { return nil }
        guard let value = AmountParser.parse(text), value > 0 else { return "Geçerli bir miktar gir" }
        if isWithdrawal && value > available {
            return "Mevcut miktardan (\(MoneyFormatter.string(available, unit))) fazla çıkarılamaz"
        }
        return nil
    }
}
