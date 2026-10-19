import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    let isTemporaryStore: Bool

    @Query(sort: \Payment.createdAt) private var queriedPayments: [Payment]
    @Query(sort: \Asset.createdAt) private var queriedAssets: [Asset]
    /// Açılış ekranı tercihi (Ayarlar / ilk açılış).
    @AppStorage(HomeMode.storageKey) private var homeModeRaw = ""
    /// Anahtarla seçilen, sadece bu oturumda geçerli ekran.
    @State private var sessionMode: HomeMode?
    @State private var showingSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var notificationsAllowed = true
    @State private var month = MonthTracker()
    @State private var rateStore = RootView.makeRateStore()

    /// Borçlar (kredi + elden); alacaklar birikim tarafında.
    private var payments: [Payment] { queriedPayments.filter { $0.isLive && $0.kind != .receivable } }

    private var receivables: [Payment] { queriedPayments.filter { $0.isLive && $0.kind == .receivable } }
    private var assets: [Asset] { queriedAssets.filter(\.isLive) }

    private var snapshots: [PaymentSnapshot] { payments.map(\.snapshot) }

    private var mode: Binding<HomeMode> {
        Binding(
            get: { sessionMode ?? HomeMode(rawValue: homeModeRaw) ?? .debt },
            set: { newMode in
                withAnimation(.easeInOut(duration: 0.25)) { sessionMode = newMode }
            })
    }

    var body: some View {
        let summary = WealthCalculator.summary(
            assets: assets.map(\.snapshot),
            payments: (payments + receivables).map(\.snapshot),
            rates: rateStore.rates)

        NavigationStack {
            if HomeMode(rawValue: homeModeRaw) == nil {
                OnboardingView { chosen in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        homeModeRaw = chosen.rawValue
                        sessionMode = chosen
                    }
                }
            } else if mode.wrappedValue == .savings {
                SavingsHomeView(assets: assets,
                                receivables: receivables,
                                summary: summary,
                                rates: rateStore.rates,
                                mode: mode,
                                onSettings: { showingSettings = true })
            } else {
                HomeView(payments: payments,
                         currentMonth: month.current,
                         rates: rateStore.rates,
                         netWorth: summary.net,
                         mode: mode,
                         onSettings: { showingSettings = true },
                         notificationsAllowed: notificationsAllowed,
                         isTemporaryStore: isTemporaryStore)
            }
        }
        .tint(mode.wrappedValue == .savings ? Theme.paid : Theme.accent)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .environment(rateStore)
        .task {
            // Açılış ekranı oturum başında bir kez okunur; Ayarlar değişikliği sonraki açılışta geçerli.
            if sessionMode == nil { sessionMode = HomeMode(rawValue: homeModeRaw) }
            #if DEBUG
            SampleData.insertIfRequested(into: context)
            #endif
            await rateStore.refreshIfNeeded(force: true)
            notificationsAllowed = await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.reschedule(payments: snapshots, rates: rateStore.rates)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-testNotification") {
                await NotificationScheduler.scheduleTest(payments: snapshots, rates: rateStore.rates)
            }
            #endif
        }
        .task(id: ScheduleInput(snapshots: snapshots, rates: rateStore.rates)) {
            await NotificationScheduler.reschedule(payments: snapshots, rates: rateStore.rates)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            month.refresh()
            Task {
                await rateStore.refreshIfNeeded()
                notificationsAllowed = await NotificationScheduler.requestAuthorization()
                await NotificationScheduler.reschedule(payments: snapshots, rates: rateStore.rates)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            month.refresh()
        }
        #if DEBUG
        .fullScreenCover(isPresented: Binding(
            get: { debugScreen != nil && !payments.isEmpty },
            set: { if !$0 { debugScreen = nil } })) {
            DebugScreen(name: debugScreen ?? "", payments: payments)
        }
        #endif
    }

    #if DEBUG
    @State private var debugScreen = SampleData.requestedScreen
    #endif

    private struct ScheduleInput: Equatable {
        let snapshots: [PaymentSnapshot]
        let rates: ExchangeRates?
    }

    private static func makeRateStore() -> RateStore {
        #if DEBUG
        if let fake = SampleData.fakeRateStore() { return fake }
        #endif
        return RateStore()
    }
}
