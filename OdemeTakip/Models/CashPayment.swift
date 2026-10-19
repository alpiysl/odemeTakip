import Foundation
import SwiftData

@Model
final class CashPayment {
    var id = UUID()
    var amount: Decimal = 0
    var date = Date.now
    var payment: Payment?

    init(amount: Decimal, date: Date) {
        self.amount = amount
        self.date = date
    }
}
