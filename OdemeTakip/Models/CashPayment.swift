import Foundation
import SwiftData

@Model
final class CashPayment {
    var id = UUID()
    var amount: Decimal = 0
    var date = Date.now
    /// Tutar ya da tarih sonradan düzeltildiyse zamanı; raporda "düzeltildi" olarak görünür.
    var correctedAt: Date?
    /// İlk düzeltmeden önceki tutar; raporda "önceki ₺…" olarak gösterilir.
    var originalAmount: Decimal?
    /// Silindiyse zamanı. Kayıt tutulur (toplamlara dahil değil) ki raporda silindiği görünsün.
    var removedAt: Date?
    var payment: Payment?

    init(amount: Decimal, date: Date) {
        self.amount = amount
        self.date = date
    }
}
