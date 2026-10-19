import Foundation

struct CashPaymentDraft: Equatable {
    var amountText = ""
    var date = Date.now
    let remaining: Decimal
    let currency: Currency
    let isReceivable: Bool

    init(remaining: Decimal, currency: Currency, isReceivable: Bool = false) {
        self.remaining = remaining
        self.currency = currency
        self.isReceivable = isReceivable
    }

    var amount: Decimal? {
        guard let value = AmountParser.parse(amountText), value > 0, value <= remaining else { return nil }
        return value
    }

    /// Boş girişte mesaj yok (Kaydet zaten pasif).
    var validationMessage: String? {
        if amountText.trimmingCharacters(in: .whitespaces).isEmpty || AmountParser.isIncomplete(amountText) { return nil }
        guard let value = AmountParser.parse(amountText), value > 0 else { return "Geçerli bir tutar gir" }
        if value > remaining {
            let limit = isReceivable ? "Kalan alacaktan" : "Kalan borçtan"
            return "\(limit) (\(MoneyFormatter.string(remaining, currency))) fazla olamaz"
        }
        return nil
    }
}
