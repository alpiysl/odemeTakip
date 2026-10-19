import SwiftUI

struct FooterTotalsView: View {
    struct Line {
        let title: String
        let value: String
        var color: Color? = nil
    }

    let lines: [Line]
    let resultTitle: String
    let resultValue: String
    /// Sonucun altında küçük ek satır (ör. "TL karşılığı ≈ ₺96.000").
    var footnote: Line? = nil

    var body: some View {
        VStack(spacing: 3) {
            ForEach(lines.indices, id: \.self) { i in
                HStack {
                    Text(lines[i].title)
                    Spacer()
                    Text(lines[i].value).foregroundStyle(lines[i].color ?? Theme.secondaryText)
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            }
            HStack {
                Text(resultTitle)
                Spacer()
                Text(resultValue)
            }
            .font(.headline.weight(.heavy))
            .padding(.top, 4)
            if let footnote {
                HStack {
                    Text(footnote.title)
                    Spacer()
                    Text(footnote.value)
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            }
        }
        .monospacedDigit()
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Theme.footer)
        .overlay(alignment: .top) { Color(hex: 0x24242C).frame(height: 1) }
    }
}

extension FooterTotalsView.Line {
    /// Döviz/altın kayıtlar için "TL karşılığı ≈ ₺X"; TL veya fiyat yoksa nil.
    static func liraEquivalent(_ amount: Decimal, _ currency: Currency, rates: ExchangeRates?) -> Self? {
        guard currency != .TRY, let lira = CurrencyConverter.toTRY([currency: amount], rates: rates) else { return nil }
        return .init(title: "TL karşılığı", value: "≈ " + MoneyFormatter.string(lira, .TRY))
    }
}
