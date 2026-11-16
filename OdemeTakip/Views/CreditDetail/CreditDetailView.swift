import SwiftData
import SwiftUI

struct CreditDetailView: View {
    let payment: Payment
    let currentMonth: YearMonth

    @Environment(RateStore.self) private var rateStore
    private var rates: ExchangeRates? { rateStore.rates }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showAll = false
    @State private var editing = false
    @State private var deleteRequested = false

    var body: some View {
        if payment.isDeleted || payment.modelContext == nil {
            Theme.background.ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        let snapshot = payment.snapshot
        let current = currentMonth
        let schedule = PaymentCalculator.schedule(snapshot, current: current)
        let rows = showAll ? schedule.allRows : schedule.visibleRows
        let amount = MoneyFormatter.string(snapshot.monthlyAmount, snapshot.currency)

        return ScrollViewReader { proxy in
            List {
                if schedule.collapsedPaidCount > 0 {
                    Button {
                        withAnimation { showAll.toggle() }
                    } label: {
                        Label(showAll ? L10n.Debt.hidePaid : L10n.Debt.showPaid(schedule.collapsedPaidCount),
                              systemImage: showAll ? "chevron.up" : "chevron.down")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                ForEach(rows) { row in
                    Button {
                        payment.toggleInstallment(row.index)
                        context.saveQuietly()
                    } label: {
                        InstallmentRowView(row: row, amount: amount)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if let receipt = Receipt.make(installment: row.index, in: payment) {
                            ShareReceiptLink(receipt: receipt)
                        }
                    }
                    .id(row.index)
                    .listRowBackground(row.isCurrent ? Theme.accent.opacity(0.08) : Color.clear)
                    .listRowSeparatorTint(Theme.divider)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onAppear {
                if let index = PaymentCalculator.installmentIndex(snapshot, in: current) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
        .pinnedTop {
            Text(L10n.Debt.creditInfo(snapshot.installmentCount, amount, snapshot.firstMonth.shortLabel))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.Debt.paidOf(PaymentCalculator.paidCount(snapshot), snapshot.installmentCount))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let next = PaymentCalculator.nextUnpaidMonth(snapshot) {
                        Text(L10n.Debt.next(next.longLabel))
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        Text(L10n.Debt.completed).font(.footnote.weight(.semibold)).foregroundStyle(Theme.paid)
                    }
                }
                ProgressBar(fraction: PaymentCalculator.progress(snapshot), height: 6)
            }
            .accessibilityElement(children: .combine)
            if !PaymentCalculator.isCompleted(snapshot) {
                Label(L10n.Debt.tapHint, systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [
                    .init(title: L10n.Debt.total, value: MoneyFormatter.string(PaymentCalculator.total(snapshot), snapshot.currency)),
                    .init(title: L10n.Debt.paidCount(PaymentCalculator.paidCount(snapshot)),
                          value: "− " + MoneyFormatter.string(PaymentCalculator.paid(snapshot), snapshot.currency),
                          color: Theme.paid),
                ],
                resultTitle: L10n.Debt.remainingCount(snapshot.installmentCount - PaymentCalculator.paidCount(snapshot)),
                resultValue: MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency),
                footnote: .liraEquivalent(PaymentCalculator.remaining(snapshot), snapshot.currency, rates: rates))
        }
        .background(Theme.background.ignoresSafeArea())
        .recordTitle(icon: payment.icon, name: payment.name)
        .toolbar {
            Button(L10n.Common.edit) { editing = true }
        }
        .sensoryFeedback(.selection, trigger: payment.paidInstallmentIndexes)
        .sheet(isPresented: $editing, onDismiss: handleSheetDismiss) {
            PaymentFormView(mode: .edit(payment), onDeleteRequested: { deleteRequested = true })
        }
    }

    private func handleSheetDismiss() {
        guard deleteRequested else { return }
        dismiss()
        PaymentDeletion.deleteAfterPop(payment, in: context)
    }
}
