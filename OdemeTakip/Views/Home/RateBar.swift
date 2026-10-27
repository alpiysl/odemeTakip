import SwiftUI

/// Kur satırı: döviz + altın satış fiyatları, yatay kaydırılabilir çipler.
struct RateBar: View {
    let rates: ExchangeRates?

    private static let shown: [(Currency, String)] = [
        (.USD, "Dolar"), (.EUR, "Euro"), (.gram, "Gram"), (.ceyrek, "Çeyrek"), (.yarim, "Yarım"), (.tam, "Tam"), (.resat, "Reşat"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let rates {
                    ForEach(items(rates), id: \.label) { item in
                        chip(item.label, item.value)
                    }
                    Text(rates.label)
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.leading, 2)
                } else {
                    Label("Kurlar yükleniyor…", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("rateBar")
    }

    private func chip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func items(_ rates: ExchangeRates) -> [(label: String, value: String)] {
        Self.shown.compactMap { currency, label in
            rates.rate(for: currency).map { (label, MoneyFormatter.string($0, .TRY)) }
        }
    }

    private var text: String {
        guard let rates else { return "Kurlar yükleniyor" }
        let parts = items(rates).map { "\($0.label) \($0.value)" }
        return (parts + [rates.label]).joined(separator: " · ")
    }
}
