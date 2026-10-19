import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    let isTemporaryStore: Bool

    @Query(sort: \Payment.createdAt) private var queriedPayments: [Payment]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @State private var notificationsAllowed = true
    @State private var month = MonthTracker()

    private var payments: [Payment] { queriedPayments.filter(\.isLive) }

    private var snapshots: [PaymentSnapshot] { payments.map(\.snapshot) }

    var body: some View {
        NavigationStack {
            HomeView(payments: payments,
                     currentMonth: month.current,
                     notificationsAllowed: notificationsAllowed,
                     isTemporaryStore: isTemporaryStore)
        }
        .tint(Theme.accent)
        .task {
            #if DEBUG
            SampleData.insertIfRequested(into: context)
            #endif
            notificationsAllowed = await NotificationScheduler.requestAuthorization()
            await NotificationScheduler.reschedule(payments: snapshots)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-testNotification") {
                await NotificationScheduler.scheduleTest(payments: snapshots)
            }
            #endif
        }
        .task(id: snapshots) {
            await NotificationScheduler.reschedule(payments: snapshots)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            month.refresh()
            Task {
                notificationsAllowed = await NotificationScheduler.requestAuthorization()
                await NotificationScheduler.reschedule(payments: snapshots)
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
}
