import SwiftUI

/// Kur satırı: döviz + altın satış fiyatları, yatay kaydırılabilir çipler.
struct RateBar: View {
    let rates: ExchangeRates?

    private static var shown: [(Currency, String)] {
        [
            (.USD, L10n.Home.rateUSD), (.EUR, L10n.Home.rateEUR), (.gram, L10n.Home.rateGram), (.ceyrek, L10n.Home.rateCeyrek),
            (.yarim, L10n.Home.rateYarim), (.tam, L10n.Home.rateTam), (.resat, L10n.Home.rateResat),
        ]
    }

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
                    Label(L10n.Home.ratesLoading, systemImage: "arrow.triangle.2.circlepath")
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
        guard let rates else { return L10n.Home.ratesLoadingAccessibility }
        let parts = items(rates).map { L10n.Home.rateItem($0.label, $0.value) }
        return (parts + [rates.label]).joined(separator: " · ")
    }
}
