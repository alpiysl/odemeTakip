import SwiftUI

struct HomeView: View {
    let payments: [Payment]
    let currentMonth: YearMonth
    let rates: ExchangeRates?
    let netWorth: Decimal?
    @Binding var mode: HomeMode
    var onSettings: () -> Void = {}
    let notificationsAllowed: Bool
    let isTemporaryStore: Bool

    @State private var filter: HomeFilter = .all
    @State private var showingAdd = false
    @AppStorage("hideNotificationBanner") private var hideNotificationBanner = false

    var body: some View {
        let snapshots = payments.map(\.snapshot)
        let filtered = payments.filter { filter.includes($0.kind) }
        let active = filtered.filter { !PaymentCalculator.isCompleted($0.snapshot) }
        let completed = filtered.filter { PaymentCalculator.isCompleted($0.snapshot) }

        ZStack(alignment: .bottomTrailing) {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if isTemporaryStore {
                        InfoBanner(text: "Veri deposu açılamadı. Girilen veriler uygulama kapanınca silinir.", onClose: nil)
                    }
                    if !notificationsAllowed && !hideNotificationBanner {
                        InfoBanner(text: "Bildirimler kapalı — Ayarlar'dan açabilirsin") {
                            hideNotificationBanner = true
                        }
                    }
                    HomeHeader(mode: $mode, onSettings: onSettings)
                    summaryCard(snapshots)
                    NetWorthRow(net: netWorth)
                    RateBar(rates: rates)
                    if payments.isEmpty {
                        emptyState
                    } else {
                        FilterBar(selection: $filter)
                        LazyVStack(spacing: 0) {
                            ForEach(active) { row($0) }
                        }
                        if !completed.isEmpty {
                            Text("Tamamlananlar")
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
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            addButton
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) {
            PaymentFormView(mode: .create)
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
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Henüz ödeme yok").font(.headline)
            Text("+ ile ilk kaydını ekle").font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var addButton: some View {
        Button {
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.gradient, in: Circle())
                .shadow(color: Theme.accent.opacity(0.45), radius: 12, y: 6)
        }
        .accessibilityLabel("Yeni ödeme")
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}
