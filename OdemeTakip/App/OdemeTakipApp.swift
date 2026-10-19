import SwiftUI
import UserNotifications

@main
struct OdemeTakipApp: App {
    private let store = PersistenceStore.make()
    @State private var showSplash = true

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        #if DEBUG
        SampleData.applyStartModeArgument()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
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
                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.3)) { showSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
