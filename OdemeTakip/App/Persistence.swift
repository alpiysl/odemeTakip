import Foundation
import OSLog
import SwiftData

enum Log {
    static let app = Logger(subsystem: "com.alpiysl.odemetakip", category: "app")
}

struct PersistenceStore {
    let container: ModelContainer?
    /// Kalıcı depo açılamadı, bellek içi çalışılıyor.
    let isTemporary: Bool

    static func make() -> PersistenceStore {
        let schema = Schema([Payment.self, CashPayment.self])
        do {
            return PersistenceStore(container: try ModelContainer(for: schema), isTemporary: false)
        } catch {
            Log.app.error("Persistent store failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            return PersistenceStore(container: try ModelContainer(for: schema, configurations: memory), isTemporary: true)
        } catch {
            Log.app.error("In-memory store failed: \(error.localizedDescription, privacy: .public)")
            return PersistenceStore(container: nil, isTemporary: true)
        }
    }
}

extension ModelContext {
    func saveQuietly() {
        do {
            try save()
        } catch {
            Log.app.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
