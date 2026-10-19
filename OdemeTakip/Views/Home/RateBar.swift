import SwiftUI

/// Ana sayfadaki kur satırı: "1$ = ₺49,55 · 1€ = ₺57,71 · TCMB 19 Eki".
struct RateBar: View {
    let rates: ExchangeRates?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.left.arrow.right").font(.caption2)
            if let rates {
                Text("1$ = \(MoneyFormatter.string(rates.usd, .TRY)) · 1€ = \(MoneyFormatter.string(rates.eur, .TRY)) · \(rates.label)")
            } else {
                Text("Kur bekleniyor")
            }
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(Theme.secondaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rateBar")
    }
}
