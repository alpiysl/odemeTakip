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

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .TRY: "₺"
        case .USD: "$"
        case .EUR: "€"
        }
    }

    var displayName: String {
        switch self {
        case .TRY: "₺ TL"
        case .USD: "$ USD"
        case .EUR: "€ EUR"
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Currency, rhs: Currency) -> Bool { lhs.order < rhs.order }
}
