import SwiftData
import SwiftUI

struct CreditDetailView: View {
    let payment: Payment

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
        let current = YearMonth(date: .now)
        let schedule = PaymentCalculator.schedule(snapshot, current: current)
        let rows = showAll ? schedule.allRows : schedule.visibleRows
        let amount = MoneyFormatter.string(snapshot.monthlyAmount, snapshot.currency)

        return ScrollViewReader { proxy in
            List {
                Text("\(snapshot.installmentCount) taksit · \(amount)/ay · \(snapshot.firstMonth.shortLabel) başlangıç")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)

                if schedule.collapsedPaidCount > 0 && !showAll {
                    Button("Önceki \(schedule.collapsedPaidCount) taksit ödendi ✓ (göster)") {
                        showAll = true
                    }
                    .font(.footnote)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [
                    .init(title: "Toplam", value: MoneyFormatter.string(PaymentCalculator.total(snapshot), snapshot.currency)),
                    .init(title: "Ödenen (\(PaymentCalculator.paidCount(snapshot)))",
                          value: "− " + MoneyFormatter.string(PaymentCalculator.paid(snapshot), snapshot.currency),
                          color: Theme.paid),
                ],
                resultTitle: "Kalan (\(snapshot.installmentCount - PaymentCalculator.paidCount(snapshot)))",
                resultValue: MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency))
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("\(payment.icon) \(payment.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button("Düzenle") { editing = true }
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
