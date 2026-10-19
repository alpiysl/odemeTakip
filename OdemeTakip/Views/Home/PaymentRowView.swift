import SwiftUI

struct PaymentRowView: View {
    let payment: Payment
    var rates: ExchangeRates? = nil

    var body: some View {
        let snapshot = payment.snapshot
        HStack(spacing: 12) {
            Text(payment.icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Theme.kindColor(snapshot.kind).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(Self.subtitle(snapshot)).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency))
                    .font(.subheadline.weight(.bold))
                if snapshot.currency != .TRY,
                   let lira = CurrencyConverter.toTRY([snapshot.currency: PaymentCalculator.remaining(snapshot)], rates: rates) {
                    Text("≈ " + MoneyFormatter.string(lira, .TRY))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .monospacedDigit()
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.divider.frame(height: 1) }
    }

    static func subtitle(_ s: PaymentSnapshot) -> String {
        switch s.kind {
        case .credit:
            "\(PaymentCalculator.paidCount(s))/\(s.installmentCount) taksit · \(MoneyFormatter.string(s.monthlyAmount, s.currency))/ay"
        case .cash:
            "Elden · \(MoneyFormatter.string(s.cashPaid, s.currency)) ödendi"
        case .receivable:
            "Alacak · \(MoneyFormatter.string(s.cashPaid, s.currency)) tahsil edildi"
        }
    }
}
