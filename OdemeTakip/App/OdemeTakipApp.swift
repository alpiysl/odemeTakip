import SwiftUI
import UserNotifications

@main
struct OdemeTakipApp: App {
    private let store = PersistenceStore.make()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = store.container {
                    RootView(isTemporaryStore: store.isTemporary)
                        .modelContainer(container)
                } else {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        InfoBanner(text: "Veri deposu açılamadı. Uygulamayı kapatıp yeniden aç.", onClose: nil)
                            .padding()
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
