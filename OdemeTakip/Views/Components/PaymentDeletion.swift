import SwiftData
import SwiftUI

enum PaymentDeletion {
    /// Detay ekranı geri kapandıktan sonra siler; silinmiş modele erişen görünüm kalmasın.
    @MainActor
    static func deleteAfterPop(_ model: some PersistentModel, in context: ModelContext) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            context.delete(model)
            context.saveQuietly()
        }
    }
}
