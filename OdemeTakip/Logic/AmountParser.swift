import Foundation

enum AmountParser {
    /// Türkçe klavye girdisini çevirir: "1.500,50", "15.000", "15000", "1500,5".
    /// Negatif, 2'den fazla küsurat veya bozuk gruplama → nil.
    static func parse(_ text: String) -> Decimal? {
        var value = text
        for token in ["₺", "$", "€", " ", "\u{00A0}"] {
            value = value.replacingOccurrences(of: token, with: "")
        }
        guard !value.isEmpty else { return nil }

        if value.contains(",") {
            if value.contains(".") {
                guard value.range(of: #"^\d{1,3}(\.\d{3})+,\d+$"#, options: .regularExpression) != nil else { return nil }
            }
            value = value.replacingOccurrences(of: ".", with: "")
            value = value.replacingOccurrences(of: ",", with: ".")
        } else if value.range(of: #"^\d{1,3}(\.\d{3})+$"#, options: .regularExpression) != nil {
            value = value.replacingOccurrences(of: ".", with: "")
        }

        guard value.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Düzenleme formu için gruplamasız metin: 1500.5 → "1500,5".
    static func editingText(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
