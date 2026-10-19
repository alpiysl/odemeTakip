import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    let isTemporaryStore: Bool

    @Query(sort: \Payment.createdAt) private var queriedPayments: [Payment]
    @Query(sort: \Asset.createdAt) private var queriedAssets: [Asset]
    @AppStorage(HomeMode.storageKey) private var homeModeRaw = ""
    @State private var toastText: String?
    @State private var toastTask: Task<Void, Never>?
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
            get: { HomeMode(rawValue: homeModeRaw) ?? .debt },
            set: { newMode in
                guard newMode.rawValue != homeModeRaw else { return }
                withAnimation(.easeInOut(duration: 0.25)) { homeModeRaw = newMode.rawValue }
                showToast("Ana ekran: \(newMode.title)")
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
                    withAnimation(.easeInOut(duration: 0.3)) { homeModeRaw = chosen.rawValue }
                }
            } else if mode.wrappedValue == .savings {
                SavingsHomeView(assets: assets,
                                receivables: receivables,
                                summary: summary,
                                rates: rateStore.rates,
                                mode: mode)
            } else {
                HomeView(payments: payments,
                         currentMonth: month.current,
                         rates: rateStore.rates,
                         netWorth: summary.net,
                         mode: mode,
                         notificationsAllowed: notificationsAllowed,
                         isTemporaryStore: isTemporaryStore)
            }
        }
        .tint(mode.wrappedValue == .savings ? Theme.paid : Theme.accent)
        .overlay(alignment: .top) {
            if let toastText {
                ToastView(text: toastText)
                    .padding(.top, 8)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .task {
            #if DEBUG
            SampleData.insertIfRequested(into: context)
            #endif
            await rateStore.refreshIfNeeded()
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

    /// 2 sn görünen, yavaşça belirip kaybolan bilgi mesajı.
    private func showToast(_ text: String) {
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.35)) { toastText = text }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) { toastText = nil }
        }
    }

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
