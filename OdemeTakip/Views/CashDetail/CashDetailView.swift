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

        return List {
            Section {
                if entries.isEmpty {
                    Text(receivable ? "Henüz tahsilat yok" : "Henüz ödeme yok")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .listRowBackground(Color.clear)
                }
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Theme.paid)
                            Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(Theme.background)
                        }
                        .frame(width: 24, height: 24)
                        Text(YearMonth(date: entry.date).longLabel)
                        Text("· \(TurkishMonths.dayMonth(entry.date))")
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
                }
                .onDelete { offsets in
                    for index in offsets { payment.removeCashPayment(entries[index]) }
                    context.saveQuietly()
                }
            } header: {
                Text(receivable ? "Tahsilat geçmişi" : "Ödeme geçmişi").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .pinnedTop {
            Text("\(receivable ? "Alacak · Toplam alacak" : "Elden · Toplam borç") \(MoneyFormatter.string(snapshot.totalDebt, snapshot.currency))")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            if completed {
                Text(receivable ? "Alacak tamamlandı ✓" : "Borç tamamlandı ✓")
                    .font(.headline)
                    .foregroundStyle(Theme.paid)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    addingPayment = true
                } label: {
                    Text(receivable ? "+ Tahsilat ekle" : "+ Ödeme ekle")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(receivable ? Theme.savingsGradient : Theme.gradient,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [
                    .init(title: receivable ? "Toplam alacak" : "Toplam borç", value: MoneyFormatter.string(snapshot.totalDebt, snapshot.currency)),
                    .init(title: "\(receivable ? "Tahsil edilen" : "Ödenen") (\(snapshot.cashPaymentCount))",
                          value: "− " + MoneyFormatter.string(snapshot.cashPaid, snapshot.currency),
                          color: Theme.paid),
                ],
                resultTitle: receivable ? "Kalan alacak" : "Kalan",
                resultValue: MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency),
                footnote: .liraEquivalent(PaymentCalculator.remaining(snapshot), snapshot.currency, rates: rates))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("\(payment.icon) \(payment.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Düzenle") { editing = true }
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
