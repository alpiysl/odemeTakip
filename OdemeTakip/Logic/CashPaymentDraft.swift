import Foundation

struct CashPaymentDraft: Equatable {
    var amountText = ""
    var date = Date.now
    let remaining: Decimal
    let currency: Currency

    init(remaining: Decimal, currency: Currency) {
        self.remaining = remaining
        self.currency = currency
    }

    var amount: Decimal? {
        guard let value = AmountParser.parse(amountText), value > 0, value <= remaining else { return nil }
        return value
    }

    /// Boş girişte mesaj yok (Kaydet zaten pasif).
    var validationMessage: String? {
        if amountText.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        guard let value = AmountParser.parse(amountText), value > 0 else { return "Geçerli bir tutar gir" }
        if value > remaining {
            return "Kalan borçtan (\(MoneyFormatter.string(remaining, currency))) fazla olamaz"
        }
        return nil
    }
}
