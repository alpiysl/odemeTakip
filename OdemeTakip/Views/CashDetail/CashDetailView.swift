import SwiftData
import SwiftUI

struct CashDetailView: View {
    let payment: Payment

    @Environment(RateStore.self) private var rateStore
    private var rates: ExchangeRates? { rateStore.rates }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var addingPayment = false
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
        let entries = payment.sortedCashPayments
        let completed = PaymentCalculator.isCompleted(snapshot)
        let receivable = payment.kind == .receivable
        let receipts = Receipt.all(in: payment)

        return List {
            Section {
                if entries.isEmpty {
                    Text(receivable ? L10n.Debt.noCollections : L10n.Debt.noPayments)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .listRowBackground(Color.clear)
                }
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Theme.paid)
                            Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(.white)
                        }
                        .frame(width: 24, height: 24)
                        Text(YearMonth(date: entry.date).longLabel)
                        Text(L10n.Debt.historyDay(TurkishMonths.dayMonth(entry.date)))
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text(MoneyFormatter.string(entry.amount, snapshot.currency))
                            .monospacedDigit()
                            .foregroundStyle(Theme.paid)
                    }
                    .font(.subheadline)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.divider)
                    .contextMenu {
                        if let receipt = receipts[entry.id] { ShareReceiptLink(receipt: receipt) }
                    }
                    .swipeActions(edge: .leading) {
                        if let receipt = receipts[entry.id] {
                            ShareReceiptLink(receipt: receipt).tint(Theme.accent)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { payment.removeCashPayment(entries[index]) }
                    context.saveQuietly()
                }
            } header: {
                Text(receivable ? L10n.Debt.collectionHistory : L10n.Debt.paymentHistory).font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .pinnedTop {
            Text(receivable
                 ? L10n.Debt.receivableInfo(MoneyFormatter.string(snapshot.totalDebt, snapshot.currency))
                 : L10n.Debt.cashInfo(MoneyFormatter.string(snapshot.totalDebt, snapshot.currency)))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            if !completed {
                ProgressBar(fraction: PaymentCalculator.progress(snapshot),
                            color: receivable ? Theme.credit : Theme.paid,
                            height: 6)
            }
            if completed {
                Text(receivable ? L10n.Debt.receivableCompleted : L10n.Debt.debtCompleted)
                    .font(.headline)
                    .foregroundStyle(Theme.paid)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    addingPayment = true
                } label: {
                    Text(receivable ? L10n.Debt.addCollectionButton : L10n.Debt.addPaymentButton)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(receivable ? Theme.savingsFill : Theme.debtFill,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [
                    .init(title: receivable ? L10n.Debt.totalReceivable : L10n.Debt.totalDebt, value: MoneyFormatter.string(snapshot.totalDebt, snapshot.currency)),
                    .init(title: receivable ? L10n.Debt.collectedCount(snapshot.cashPaymentCount) : L10n.Debt.paidCount(snapshot.cashPaymentCount),
                          value: "− " + MoneyFormatter.string(snapshot.cashPaid, snapshot.currency),
                          color: Theme.paid),
                ],
                resultTitle: receivable ? L10n.Debt.remainingReceivable : L10n.Debt.remaining,
                resultValue: MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency),
                footnote: .liraEquivalent(PaymentCalculator.remaining(snapshot), snapshot.currency, rates: rates))
        }
        .background(Theme.background.ignoresSafeArea())
        .recordTitle(icon: payment.icon, name: payment.name)
        .toolbar {
            Button(L10n.Common.edit) { editing = true }
        }
        .sheet(isPresented: $addingPayment) {
            AddCashPaymentView(payment: payment)
        }
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
