import SwiftUI

struct SummaryCardView: View {
    let snapshots: [PaymentSnapshot]
    let currentMonth: YearMonth
    let rates: ExchangeRates?

    var body: some View {
        let totals = PaymentCalculator.totals(snapshots)
        let lira = CurrencyConverter.toTRY(totals.overall, rates: rates)
        let primary = lira == nil ? PaymentCalculator.primaryCurrency(snapshots) : .TRY
        let others = lira == nil ? totals.overall.filter { $0.key != primary } : [:]

        VStack(alignment: .leading, spacing: 2) {
            Text("Toplam kalan").font(.caption).opacity(0.85)
            Text(MoneyFormatter.string(lira ?? totals.overall[primary] ?? 0, primary))
                .font(.system(size: 36, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !others.isEmpty {
                Text("+ " + MoneyFormatter.joined(others)).font(.footnote).opacity(0.85)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { legends(totals) }
                VStack(alignment: .leading, spacing: 4) { legends(totals) }
            }
            .font(.caption)
            .padding(.top, 8)
            chip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func legends(_ totals: Totals) -> some View {
        legend(color: Theme.credit, title: "Kredi", value: MoneyFormatter.total(totals.credit, rates: rates))
        legend(color: Theme.cash, title: "Elden", value: MoneyFormatter.total(totals.cash, rates: rates))
    }

    private func legend(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
            Text(value).fontWeight(.bold)
        }
    }

    @ViewBuilder
    private var chip: some View {
        switch PaymentCalculator.thisMonthStatus(snapshots, in: currentMonth) {
        case .none:
            EmptyView()
        case .allPaid:
            chipText("Bu ayın taksitleri ödendi ✓")
        case .due(let due):
            chipText("Bu ay: \(MoneyFormatter.total(due.mapValues(\.amount), rates: rates)) kredi taksiti")
        }
    }

    private func chipText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.top, 10)
    }
}
