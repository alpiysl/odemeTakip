import Foundation

/// TCMB döviz satış kurları (1 birim döviz = x TL).
struct ExchangeRates: Codable, Equatable, Sendable {
    var usd: Decimal
    var eur: Decimal
    /// TCMB bülten tarihi.
    var bulletinDate: Date
    /// Telefona alındığı an.
    var fetchedAt: Date
    /// Altın satış fiyatları (Currency.rawValue → TL). Eski kayıtlarda yok.
    var gold: [String: Decimal]? = nil

    func rate(for currency: Currency) -> Decimal? {
        switch currency {
        case .TRY: 1
        case .USD: usd
        case .EUR: eur
        case .gram, .ceyrek, .yarim, .tam, .resat: gold?[currency.rawValue]
        }
    }

    var label: String { "TCMB \(TurkishMonths.dayMonth(bulletinDate))" }
}

enum CurrencyConverter {
    /// Tutarların TL toplamı. Döviz varsa ve kur yoksa nil. Döviz karşılıkları tam liraya yuvarlanır.
    static func toTRY(_ amounts: [Currency: Decimal], rates: ExchangeRates?) -> Decimal? {
        var total: Decimal = 0
        for (currency, amount) in amounts {
            if currency == .TRY {
                total += amount
            } else {
                guard let rate = rates?.rate(for: currency) else { return nil }
                total += (amount * rate).roundedToWhole
            }
        }
        return total
    }
}

extension MoneyFormatter {
    /// Kur varsa tek TL toplamı, yoksa para birimleri ayrı ("₺50.000 + $2.400").
    static func total(_ amounts: [Currency: Decimal], rates: ExchangeRates?) -> String {
        if let lira = CurrencyConverter.toTRY(amounts, rates: rates) {
            return string(lira, .TRY)
        }
        return joined(amounts)
    }
}

/// Piyasa servisinden (truncgil) altın ve yedek döviz satış fiyatları.
struct MarketPrices: Equatable, Sendable {
    var gold: [Currency: Decimal]
    var usd: Decimal?
    var eur: Decimal?
}

enum GoldParser {
    private static let keys: [Currency: String] = [
        .gram: "GRA", .ceyrek: "CEYREKALTIN", .yarim: "YARIMALTIN", .tam: "TAMALTIN", .resat: "RESATALTIN",
    ]

    /// Bozuk JSON veya hiç altın yoksa nil.
    static func parse(_ data: Data) -> MarketPrices? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func selling(_ key: String) -> Decimal? {
            guard let entry = root[key] as? [String: Any], let number = entry["Selling"] as? NSNumber,
                  let value = Decimal(string: number.stringValue, locale: Locale(identifier: "en_US_POSIX")),
                  value > 0 else { return nil }
            return value
        }
        var gold: [Currency: Decimal] = [:]
        for (currency, key) in keys {
            if let value = selling(key) { gold[currency] = value }
        }
        guard !gold.isEmpty else { return nil }
        return MarketPrices(gold: gold, usd: selling("USD"), eur: selling("EUR"))
    }
}

/// TCMB today.xml okuyucu: USD ve EUR `ForexSelling`.
enum TCMBParser {
    static func parse(_ data: Data, fetchedAt: Date) -> ExchangeRates? {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(),
              let date = delegate.bulletinDate,
              let usd = delegate.selling["USD"], usd > 0,
              let eur = delegate.selling["EUR"], eur > 0 else { return nil }
        return ExchangeRates(usd: usd, eur: eur, bulletinDate: date, fetchedAt: fetchedAt)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var bulletinDate: Date?
        var selling: [String: Decimal] = [:]
        private var code: String?
        private var unit: Decimal = 1
        private var element = ""
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes: [String: String] = [:]) {
            element = elementName
            text = ""
            switch elementName {
            case "Tarih_Date":
                bulletinDate = attributes["Tarih"].flatMap(Self.date(from:))
            case "Currency":
                code = attributes["CurrencyCode"] ?? attributes["Kod"]
                unit = 1
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            let value = Decimal(string: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                locale: Locale(identifier: "en_US_POSIX"))
            switch elementName {
            case "Unit":
                if let value, value > 0 { unit = value }
            case "ForexSelling":
                if let code, let value { selling[code] = value / unit }
            case "Currency":
                code = nil
            default:
                break
            }
            text = ""
        }

        private static func date(from text: String) -> Date? {
            let parts = text.split(separator: ".").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return AppCalendar.calendar.date(from: DateComponents(year: parts[2], month: parts[1], day: parts[0]))
        }
    }
}
