import SwiftUI

struct PaymentRowView: View {
    let payment: Payment
    var rates: ExchangeRates? = nil

    var body: some View {
        let snapshot = payment.snapshot
        HStack(spacing: 12) {
            PaymentIconView(icon: payment.icon, tint: Theme.kindColor(snapshot.kind))
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(Self.subtitle(snapshot)).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
                if !PaymentCalculator.isCompleted(snapshot) {
                    HStack(spacing: 6) {
                        ProgressBar(fraction: PaymentCalculator.progress(snapshot),
                                    color: Theme.kindColor(snapshot.kind == .receivable ? .credit : snapshot.kind))
                        if snapshot.kind == .credit {
                            Text(L10n.Home.installmentProgress(PaymentCalculator.paidCount(snapshot), snapshot.installmentCount))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency))
                    .font(.subheadline.weight(.bold))
                if snapshot.currency != .TRY,
                   let lira = CurrencyConverter.toTRY([snapshot.currency: PaymentCalculator.remaining(snapshot)], rates: rates) {
                    Text(L10n.Common.approx(MoneyFormatter.string(lira, .TRY)))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .layoutPriority(1)
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.divider.frame(height: 1) }
    }

    static func subtitle(_ s: PaymentSnapshot) -> String {
        switch s.kind {
        case .credit:
            if let next = PaymentCalculator.nextUnpaidMonth(s) {
                L10n.Home.rowCreditNext(MoneyFormatter.string(s.monthlyAmount, s.currency), next.shortLabel)
            } else {
                L10n.Home.rowCredit(PaymentCalculator.paidCount(s), s.installmentCount, MoneyFormatter.string(s.monthlyAmount, s.currency))
            }
        case .cash:
            L10n.Home.rowCash(MoneyFormatter.string(s.cashPaid, s.currency))
        case .receivable:
            L10n.Home.rowReceivable(MoneyFormatter.string(s.cashPaid, s.currency))
        }
    }
}
