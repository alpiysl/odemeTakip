import SwiftUI

/// Kur satırı: döviz + altın satış fiyatları, yatay kaydırılabilir.
struct RateBar: View {
    let rates: ExchangeRates?

    private static let shown: [(Currency, String)] = [
        (.USD, "$"), (.EUR, "€"), (.gram, "Gr"), (.ceyrek, "Çyr"), (.yarim, "Yrm"), (.tam, "Tam"), (.resat, "Reşat"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right").font(.caption2)
                Text(text)
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityIdentifier("rateBar")
    }

    private var text: String {
        guard let rates else { return "Kur bekleniyor" }
        let parts = Self.shown.compactMap { currency, label in
            rates.rate(for: currency).map { "\(label) \(MoneyFormatter.string($0, .TRY))" }
        }
        return (parts + [rates.label]).joined(separator: " · ")
    }
}
