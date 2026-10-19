import Foundation

enum MoneyFormatter {
    static func string(_ amount: Decimal, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        let hasFraction = amount != amount.roundedToWhole
        formatter.minimumFractionDigits = hasFraction ? 2 : 0
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return currency.symbol + number
    }

    /// Para birimlerini sırayla "₺50.000 + $2.400" şeklinde birleştirir; sıfırları atlar.
    static func joined(_ amounts: [Currency: Decimal]) -> String {
        let parts = amounts
            .filter { $0.value != 0 }
            .sorted { $0.key < $1.key }
            .map { string($0.value, $0.key) }
        return parts.isEmpty ? string(0, .TRY) : parts.joined(separator: " + ")
    }
}

extension Decimal {
    var roundedToWhole: Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, 0, .plain)
        return result
    }
}
