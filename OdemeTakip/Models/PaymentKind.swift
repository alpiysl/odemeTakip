import Foundation

enum PaymentKind: String, CaseIterable, Codable, Sendable {
    case credit
    case cash
    /// Birikim tarafı: sana borçlu olunan tutar (elden borcun aynası).
    case receivable

    var title: String {
        switch self {
        case .credit: L10n.Models.kindCredit
        case .cash: L10n.Models.kindCash
        case .receivable: L10n.Models.kindReceivable
        }
    }
}

enum Currency: String, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case TRY
    case USD
    case EUR
    case gram
    case ceyrek
    case yarim
    case tam
    case resat

    /// Borçlarda seçilebilen para birimleri.
    static let fiatCases: [Currency] = [.TRY, .USD, .EUR]

    var id: String { rawValue }

    var isGold: Bool { !Self.fiatCases.contains(self) }

    /// Altın birimi adı: "gr", "çeyrek", ...
    var unitName: String {
        switch self {
        case .TRY, .USD, .EUR: ""
        case .gram: L10n.Models.unitGram
        case .ceyrek: L10n.Models.unitCeyrek
        case .yarim: L10n.Models.unitYarim
        case .tam: L10n.Models.unitTam
        case .resat: L10n.Models.unitResat
        }
    }

    var symbol: String {
        switch self {
        case .TRY: "₺"
        case .USD: "$"
        case .EUR: "€"
        case .gram, .ceyrek, .yarim, .tam, .resat: ""
        }
    }

    var displayName: String {
        switch self {
        case .TRY: L10n.Models.currencyTRY
        case .USD: L10n.Models.currencyUSD
        case .EUR: L10n.Models.currencyEUR
        case .gram: L10n.Models.currencyGram
        case .ceyrek: L10n.Models.currencyCeyrek
        case .yarim: L10n.Models.currencyYarim
        case .tam: L10n.Models.currencyTam
        case .resat: L10n.Models.currencyResat
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Currency, rhs: Currency) -> Bool { lhs.order < rhs.order }
}
