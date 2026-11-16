import SwiftUI

struct HomeView: View {
    let payments: [Payment]
    let currentMonth: YearMonth
    let rates: ExchangeRates?
    let netWorth: Decimal?
    @Binding var mode: HomeMode
    var onSettings: () -> Void = {}
    var onReport: () -> Void = {}
    var onImportPDF: () -> Void = {}
    let notificationsAllowed: Bool
    let isTemporaryStore: Bool

    @State private var filter: HomeFilter = .all
    @State private var showingAdd = false
    @State private var cashTarget: Payment?
    @Environment(\.modelContext) private var context
    @AppStorage("hideNotificationBanner") private var hideNotificationBanner = false

    var body: some View {
        let snapshots = payments.map(\.snapshot)
        let filtered = payments.filter { filter.includes($0.kind) }
        let active = filtered.filter { !PaymentCalculator.isCompleted($0.snapshot) }
        let completed = filtered.filter { PaymentCalculator.isCompleted($0.snapshot) }

        PinnedLayout {
            if isTemporaryStore {
                InfoBanner(text: L10n.Home.storeUnavailable, onClose: nil)
            }
            if !notificationsAllowed && !hideNotificationBanner {
                InfoBanner(text: L10n.Home.notificationsOff) {
                    hideNotificationBanner = true
                }
            }
            HomeHeader(mode: $mode, onSettings: onSettings, onReport: onReport)
            summaryCard(snapshots)
            NetWorthRow(net: netWorth)
            RateBar(rates: rates)
            if !payments.isEmpty {
                FilterBar(selection: $filter)
            }
        } content: {
            if payments.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(active) { row($0) }
                }
                if !completed.isEmpty {
                    Text(L10n.Common.completedSection)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 8)
                    LazyVStack(spacing: 0) {
                        ForEach(completed) { row($0).opacity(0.5) }
                    }
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .addBar {
            Menu {
                Button(L10n.Documents.importManual, systemImage: "square.and.pencil") { showingAdd = true }
                Button(L10n.Documents.importFromPDF, systemImage: "doc.viewfinder", action: onImportPDF)
            } label: {
                AddBarLabel(title: L10n.Home.newPayment, gradient: Theme.gradient)
            }
            .accessibilityLabel(L10n.Home.newPayment)
            .accessibilityIdentifier("addMenu")
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) {
            PaymentFormView(mode: .create)
        }
        .sheet(item: $cashTarget) { payment in
            AddCashPaymentView(payment: payment)
        }
    }

    @ViewBuilder
    private func summaryCard(_ snapshots: [PaymentSnapshot]) -> some View {
        let card = SummaryCardView(snapshots: snapshots, currentMonth: currentMonth, rates: rates)
        #if DEBUG
        card.onLongPressGesture {
            Task { await NotificationScheduler.scheduleTest(payments: snapshots, rates: rates) }
        }
        #else
        card
        #endif
    }

    private func row(_ payment: Payment) -> some View {
        NavigationLink {
            switch payment.kind {
            case .credit: CreditDetailView(payment: payment, currentMonth: currentMonth)
            case .cash, .receivable: CashDetailView(payment: payment)
            }
        } label: {
            PaymentRowView(payment: payment, rates: rates)
        }
        .buttonStyle(.plain)
        .contextMenu { quickActions(payment) }
    }

    /// Uzun basınca: detaya girmeden bu ayın taksitini işaretle / ödeme ekle.
    @ViewBuilder
    private func quickActions(_ payment: Payment) -> some View {
        let snapshot = payment.snapshot
        switch payment.kind {
        case .credit:
            if let index = PaymentCalculator.installmentIndex(snapshot, in: currentMonth) {
                let paid = snapshot.paidInstallments.contains(index)
                Button(paid ? L10n.Home.markThisMonthUnpaid : L10n.Home.markThisMonthPaid,
                       systemImage: paid ? "arrow.uturn.backward.circle" : "checkmark.circle") {
                    payment.toggleInstallment(index)
                    context.saveQuietly()
                }
            }
        case .cash, .receivable:
            if !PaymentCalculator.isCompleted(snapshot) {
                Button(L10n.Home.addPayment, systemImage: "plus.circle") { cashTarget = payment }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(systemImage: "creditcard",
                       title: L10n.Home.emptyTitle,
                       message: L10n.Home.emptyMessage)
    }
}
