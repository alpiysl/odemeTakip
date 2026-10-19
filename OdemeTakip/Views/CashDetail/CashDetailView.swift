import SwiftData
import SwiftUI

struct CashDetailView: View {
    let payment: Payment

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

        return List {
            Section {
                Text("Elden · Toplam borç \(MoneyFormatter.string(snapshot.totalDebt, snapshot.currency))")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)

                if completed {
                    Text("Borç tamamlandı ✓")
                        .font(.headline)
                        .foregroundStyle(Theme.paid)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    Button {
                        addingPayment = true
                    } label: {
                        Text("+ Ödeme ekle")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Section {
                if entries.isEmpty {
                    Text("Henüz ödeme yok")
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
                Text("Ödeme geçmişi").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [
                    .init(title: "Toplam borç", value: MoneyFormatter.string(snapshot.totalDebt, snapshot.currency)),
                    .init(title: "Ödenen (\(snapshot.cashPaymentCount))",
                          value: "− " + MoneyFormatter.string(snapshot.cashPaid, snapshot.currency),
                          color: Theme.paid),
                ],
                resultTitle: "Kalan",
                resultValue: MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("\(payment.icon) \(payment.name)")
        .navigationBarTitleDisplayMode(.large)
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
