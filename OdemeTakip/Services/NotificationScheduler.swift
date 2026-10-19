import Foundation
import UserNotifications

@MainActor
enum NotificationScheduler {
    private static let monthlyPrefix = "monthly-"

    /// İzin hiç sorulmadıysa sorar. Bildirim gösterilebiliyorsa true.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                Log.app.error("Notification auth failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        case .denied:
            return false
        default:
            return true
        }
    }

    /// Bekleyen tüm aylık bildirimleri silip önümüzdeki 12 ay için yeniden kurar.
    static func reschedule(payments: [PaymentSnapshot], now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let monthlyIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(monthlyPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: monthlyIDs)
        for month in NotificationContentBuilder.triggerMonths(after: now) {
            guard let content = NotificationContentBuilder.content(for: month, payments: payments) else { continue }
            var components = DateComponents()
            components.year = month.year
            components.month = month.month
            components.day = 1
            components.hour = NotificationContentBuilder.hour
            components.minute = 0
            let request = UNNotificationRequest(
                identifier: "\(monthlyPrefix)\(month.year)-\(month.month)",
                content: makeContent(content),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
            } catch {
                Log.app.error("Schedule failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    #if DEBUG
    /// 5 sn sonra bu ayın bildirimini gösterir (sadece Debug build).
    static func scheduleTest(payments: [PaymentSnapshot]) async {
        let month = YearMonth(date: .now)
        let content = NotificationContentBuilder.content(for: month, payments: payments)
            ?? NotificationContent(title: "\(month.name) ödemeleri", body: "Bu ay ödeme yok")
        let request = UNNotificationRequest(
            identifier: "debug-test",
            content: makeContent(content),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif

    private static func makeContent(_ content: NotificationContent) -> UNMutableNotificationContent {
        let result = UNMutableNotificationContent()
        result.title = content.title
        result.body = content.body
        result.sound = .default
        return result
    }
}

/// Uygulama açıkken de bildirimi banner olarak gösterir.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
