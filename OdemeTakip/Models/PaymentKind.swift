import Foundation

enum PaymentKind: String, CaseIterable, Codable, Sendable {
    case credit
    case cash

    var title: String {
        switch self {
        case .credit: "Kredi"
        case .cash: "Elden"
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
        case .gram: "gr"
        case .ceyrek: "çeyrek"
        case .yarim: "yarım"
        case .tam: "tam"
        case .resat: "reşat"
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
        case .TRY: "₺ TL"
        case .USD: "$ USD"
        case .EUR: "€ EUR"
        case .gram: "Gram altın"
        case .ceyrek: "Çeyrek altın"
        case .yarim: "Yarım altın"
        case .tam: "Tam altın"
        case .resat: "Reşat altın"
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Currency, rhs: Currency) -> Bool { lhs.order < rhs.order }
}
