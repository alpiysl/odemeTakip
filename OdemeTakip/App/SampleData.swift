#if DEBUG
import Foundation
import SwiftData
import SwiftUI

/// `-seedSampleData` argümanıyla açılırsa ve veri yoksa örnek kayıtlar ekler.
enum SampleData {
    @MainActor
    static func insertIfRequested(into context: ModelContext) {
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            for payment in (try? context.fetch(FetchDescriptor<Payment>())) ?? [] {
                context.delete(payment)
            }
            for asset in (try? context.fetch(FetchDescriptor<Asset>())) ?? [] {
                context.delete(asset)
            }
            context.saveQuietly()
        }
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

        var mehmet = PaymentDraft(firstMonth: now)
        mehmet.kind = .receivable; mehmet.name = "Mehmet"; mehmet.icon = "💰"; mehmet.totalDebtText = "150000"
        if let receivable = Payment.make(from: mehmet) {
            context.insert(receivable)
            receivable.addCashPayment(amount: 30_000, date: .now)
        }

        let assets: [(String, Currency, [Decimal])] = [
            ("Altın", .gram, [45, 10, -5]),
            ("Çeyrekler", .ceyrek, [12]),
            ("Dolar hesabı", .USD, [10_000]),
            ("Vadeli TL", .TRY, [209_319]),
        ]
        for (name, unit, amounts) in assets {
            var draft = AssetDraft()
            draft.name = name
            draft.unit = unit
            draft.icon = AssetDraft.defaultIcon(for: unit)
            draft.amountText = "\(amounts[0])"
            guard let asset = Asset.make(from: draft, in: context) else { continue }
            for (offset, amount) in amounts.dropFirst().enumerated() {
                asset.addMovement(amount: amount, date: .now.addingTimeInterval(Double(offset + 1) * 60))
            }
        }

        if ProcessInfo.processInfo.arguments.contains("-seedMany") {
            for index in 1...15 {
                var extra = PaymentDraft(firstMonth: now)
                extra.kind = .cash
                extra.name = "Ek borç \(index)"
                extra.totalDebtText = "\(index * 1_000)"
                if let payment = Payment.make(from: extra) { context.insert(payment) }
            }
        }

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

    /// `-fakeRates`: ağsız, sabit kur (1$ = ₺40, 1€ = ₺50).
    @MainActor
    static func fakeRateStore() -> RateStore? {
        guard ProcessInfo.processInfo.arguments.contains("-fakeRates") else { return nil }
        let suite = "debug-fake-rates"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let xml = """
        <Tarih_Date Tarih="19.10.2026"><Currency CurrencyCode="USD"><Unit>1</Unit><ForexSelling>40</ForexSelling></Currency>\
        <Currency CurrencyCode="EUR"><Unit>1</Unit><ForexSelling>50</ForexSelling></Currency></Tarih_Date>
        """
        let gold = """
        {"GRA":{"Selling":6000},"CEYREKALTIN":{"Selling":10000},"YARIMALTIN":{"Selling":20000},\
        "TAMALTIN":{"Selling":40000},"RESATALTIN":{"Selling":41000}}
        """
        return RateStore(defaults: defaults, fetch: { Data(xml.utf8) }, fetchGold: { Data(gold.utf8) })
    }

    /// `-startMode <debt|savings|none>`: ana ekran tercihini ayarlar (none = ilk açılış seçimi).
    static func applyStartModeArgument() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-startMode"), index + 1 < args.count else { return }
        let value = args[index + 1]
        if value == "none" {
            UserDefaults.standard.removeObject(forKey: HomeMode.storageKey)
        } else {
            UserDefaults.standard.set(value, forKey: HomeMode.storageKey)
        }
    }

    /// `-debugScreen <credit|cash|form>` argümanının değeri.
    static var requestedScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-debugScreen"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}

/// Ekran görüntüsü kontrolü için ekranı doğrudan açar (sadece Debug).
struct DebugScreen: View {
    let name: String
    let payments: [Payment]

    var body: some View {
        switch name {
        case "credit":
            if let payment = payments.first(where: { $0.kind == .credit }) {
                NavigationStack { CreditDetailView(payment: payment, currentMonth: YearMonth(date: .now)) }
            }
        case "cash":
            if let payment = payments.first(where: { $0.kind == .cash }) {
                NavigationStack { CashDetailView(payment: payment) }
            }
        default:
            PaymentFormView(mode: .create)
        }
    }
}
#endif
