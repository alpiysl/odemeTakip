#if DEBUG
import Foundation
import SwiftData

/// `-seedSampleData` argümanıyla açılırsa ve veri yoksa örnek kayıtlar ekler.
enum SampleData {
    @MainActor
    static func insertIfRequested(into context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleData"),
              (try? context.fetchCount(FetchDescriptor<Payment>())) == 0 else { return }

        let now = YearMonth(date: .now)

        var home = PaymentDraft(firstMonth: now.adding(months: -13))
        home.kind = .credit; home.name = "Konut Kredisi"; home.icon = "🏠"
        home.installmentCountText = "36"; home.monthlyAmountText = "15000"; home.prepaidCountText = "13"

        var car = PaymentDraft(firstMonth: now.adding(months: -8))
        car.kind = .credit; car.name = "Araç Kredisi"; car.icon = "🚗"
        car.installmentCountText = "16"; car.monthlyAmountText = "7500"; car.prepaidCountText = "8"

        var friend = PaymentDraft(firstMonth: now)
        friend.kind = .cash; friend.name = "Ahmet'e borç"; friend.icon = "🤝"; friend.totalDebtText = "80000"

        var dollar = PaymentDraft(firstMonth: now)
        dollar.kind = .cash; dollar.name = "Dolar borcu"; dollar.icon = "💵"
        dollar.currency = .USD; dollar.totalDebtText = "3000"

        for draft in [home, car, friend, dollar] {
            guard let payment = Payment.make(from: draft) else { continue }
            context.insert(payment)
            if draft.name == "Ahmet'e borç" {
                payment.addCashPayment(amount: 10_000, date: .now)
                payment.addCashPayment(amount: 20_000, date: .now.addingTimeInterval(-40 * 86_400))
            }
            if draft.name == "Dolar borcu" {
                payment.addCashPayment(amount: 600, date: .now)
            }
        }
        context.saveQuietly()
    }
}
#endif
