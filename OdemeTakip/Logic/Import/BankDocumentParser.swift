import Foundation

/// Banka PDF'inden okunan borç bilgileri. Her alan isteğe bağlı; kullanıcı formda kontrol eder.
struct ParsedDebt: Equatable, Sendable {
    enum Field: String, CaseIterable, Sendable {
        case bank, monthlyAmount, installmentCount, firstMonth, paidCount, totalDebt

        var title: String {
            switch self {
            case .bank: L10n.Documents.fieldBank
            case .monthlyAmount: L10n.Documents.fieldMonthly
            case .installmentCount: L10n.Documents.fieldCount
            case .firstMonth: L10n.Documents.fieldFirstMonth
            case .paidCount: L10n.Documents.fieldPaidCount
            case .totalDebt: L10n.Documents.fieldTotalDebt
            }
        }
    }

    var bank: Bank?
    var kind: PaymentKind?
    var currency: Currency = .TRY
    var monthlyAmount: Decimal?
    var installmentCount: Int?
    var firstMonth: YearMonth?
    var paidCount: Int?
    var totalDebt: Decimal?
    var suggestedName: String?

    /// Hiçbir borç bilgisi bulunamadı.
    var isEmpty: Bool { kind == nil }

    var foundFields: [Field] {
        var fields: [Field] = []
        if bank != nil { fields.append(.bank) }
        if monthlyAmount != nil { fields.append(.monthlyAmount) }
        if installmentCount != nil { fields.append(.installmentCount) }
        if firstMonth != nil { fields.append(.firstMonth) }
        if paidCount != nil { fields.append(.paidCount) }
        if totalDebt != nil { fields.append(.totalDebt) }
        return fields
    }

    /// Formun üstündeki bilgi: neler okundu ya da hiçbir şey okunamadı.
    var bannerText: String {
        isEmpty
            ? L10n.Documents.importNothingFound
            : L10n.Documents.importFound(foundFields.map(\.title).joined(separator: ", "))
    }

    /// Formu önceden dolduran taslak.
    func makeDraft(today: YearMonth) -> PaymentDraft {
        let kind = kind ?? .credit
        var draft = PaymentDraft(firstMonth: firstMonth ?? today)
        draft.kind = kind
        draft.name = suggestedName ?? ""
        draft.icon = bank?.iconValue ?? PaymentDraft.defaultIcon(for: kind)
        draft.currency = currency
        switch kind {
        case .credit:
            draft.installmentCountText = installmentCount.map(String.init) ?? ""
            draft.monthlyAmountText = monthlyAmount.map(AmountParser.editingText) ?? ""
            draft.prepaidCountText = paidCount.map(String.init) ?? ""
        case .cash, .receivable:
            draft.totalDebtText = totalDebt.map(AmountParser.editingText) ?? ""
        }
        return draft
    }
}

/// Banka belgesi metninden (PDF metni ya da OCR) kredi / kart borcu bilgilerini çıkarır.
/// Etiketlere ("Taksit Tutarı", "Vade Sayısı"…) ve ödeme planı tablosuna bakar; banka şablonu gerektirmez.
enum BankDocumentParser {
    static func parse(_ text: String, today: YearMonth) -> ParsedDebt {
        let lines = text.foldedForMatching
            .components(separatedBy: .newlines)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }

        var result = ParsedDebt()
        result.bank = Bank.detect(in: text)
        let monthlyMatch = amountMatch(after: Labels.monthly, excluding: Labels.monthlyExclusions, in: lines)
        var monthly = monthlyMatch?.value
        var count = integer(after: Labels.count, excluding: Labels.countExclusions, in: lines)
        var first = date(after: Labels.firstDate, in: lines)
        let explicitPaid = integer(after: Labels.paid, excluding: [], in: lines)
        let repayment = amount(after: Labels.totalRepayment, in: lines)

        if let plan = paymentPlan(in: lines) {
            // Tablodaki satır numaraları, serbest "vade" etiketinden daha güvenilir.
            count = plan.count
            first = first ?? plan.first
            monthly = monthly ?? plan.monthly
        }
        if monthly == nil, let repayment, let count, count > 0 {
            monthly = rounded(repayment / Decimal(count))
        }

        let isCardStatement = lines.contains { line in Labels.cardMarkers.contains { line.contains($0) } }
        let debtMatch = amountMatch(after: Labels.cardDebt, in: lines)
        // Para birimi: önce ana tutarın yanındaki birim, yoksa belgenin genelinde en çok geçen.
        let keyCurrency = isCardStatement ? (debtMatch?.currency ?? monthlyMatch?.currency) : (monthlyMatch?.currency ?? debtMatch?.currency)
        result.currency = keyCurrency ?? currency(in: lines)

        if isCardStatement, let debt = debtMatch?.value {
            // Ekstrede "gelecek dönem taksit tutarı" gibi satırlar olsa da bu bir kart borcu.
            result.kind = .cash
            result.totalDebt = debt
            result.suggestedName = result.bank.map { L10n.Documents.cardName($0.name) }
        } else if monthly != nil || count != nil {
            result.kind = .credit
            result.monthlyAmount = monthly
            result.installmentCount = count
            result.firstMonth = first
            if let explicitPaid {
                result.paidCount = explicitPaid
            } else if let first {
                let elapsed = max(0, today.months(from: first))
                result.paidCount = count.map { min(elapsed, $0) } ?? elapsed
            }
            result.suggestedName = result.bank.map { L10n.Documents.loanName($0.name) }
        } else if let debt = amount(after: Labels.cardDebt, in: lines) {
            result.kind = .cash
            result.totalDebt = debt
            result.suggestedName = result.bank.map { L10n.Documents.cardName($0.name) }
        }
        return result
    }

    // MARK: Etiketler (foldedForMatching biçiminde)

    private enum Labels {
        static let monthly = ["taksit tutari", "aylik taksit", "aylik odeme tutari", "aylik odeme"]
        /// "Kalan / ödenen / gelecek dönem taksit tutarı" aylık taksit değildir.
        static let monthlyExclusions = ["toplam", "kalan", "odenen", "odenmis", "gelecek", "gecikmis", "donem"]
        static let count = ["taksit sayisi", "vade sayisi", "toplam taksit", "vade suresi", "kredi vadesi", "vade (ay)", "vade"]
        static let countExclusions = ["odenen", "odenmis", "kalan", "tarihi", "gunu", "hesap"]
        static let paid = ["odenen taksit sayisi", "odenmis taksit sayisi", "odenen taksit"]
        static let firstDate = ["ilk taksit tarihi", "ilk taksit odeme tarihi", "ilk odeme tarihi"]
        static let totalRepayment = ["toplam geri odeme", "geri odenecek toplam", "toplam odeme tutari"]
        static let cardDebt = ["donem borcu", "hesap ozeti borcu", "toplam borc"]
        /// Bunlardan biri varsa belge kredi kartı ekstresidir.
        static let cardMarkers = ["donem borcu", "son odeme tarihi", "asgari odeme"]
    }

    /// Türkçe tutar: "4.812,35" / "250,00". Sınırlar, "4,812.35" (İngilizce) ve "1234.567,89" gibi
    /// biçimlerin bir parçasının yanlışlıkla okunmasını engeller.
    private static let amountPattern = #"(?<![\d.,])(?:\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2})(?![\d,]|\.\d)"#
    private static let numericDatePattern = #"(\d{1,2})[./-](\d{1,2})[./-](\d{4})"#
    private static let monthNames = ["ocak", "subat", "mart", "nisan", "mayis", "haziran",
                                     "temmuz", "agustos", "eylul", "ekim", "kasim", "aralik"]

    // MARK: Değer bulma

    /// Etiketten sonraki metin; etiket satırda yalnızsa bir sonraki satır.
    private static func values(after labels: [String], excluding: [String] = [], in lines: [String]) -> [String] {
        var found: [String] = []
        for label in labels {
            // Etiket kelime olarak geçmeli: "vade" ≠ "vadesiz".
            let pattern = "(?<![a-z])" + NSRegularExpression.escapedPattern(for: label) + "(?![a-z])"
            for (index, line) in lines.enumerated() {
                guard let range = line.range(of: pattern, options: .regularExpression),
                      !excluding.contains(where: { line.contains($0) }) else { continue }
                let rest = String(line[range.upperBound...])
                if rest.trimmingCharacters(in: CharacterSet(charactersIn: " :.-()")).isEmpty {
                    if index + 1 < lines.count { found.append(lines[index + 1]) }
                } else {
                    found.append(rest)
                }
            }
        }
        return found
    }

    private static func amount(after labels: [String], excluding: [String] = [], in lines: [String]) -> Decimal? {
        amountMatch(after: labels, excluding: excluding, in: lines)?.value
    }

    /// Etiketten sonraki ilk tutar ve hemen yanındaki para birimi ("4.812,35 TL", "4.812,35TL", "$500,00").
    private static func amountMatch(after labels: [String], excluding: [String] = [],
                                    in lines: [String]) -> (value: Decimal, currency: Currency?)? {
        for text in values(after: labels, excluding: excluding, in: lines) {
            guard let match = text.range(of: amountPattern, options: .regularExpression),
                  let value = AmountParser.parse(String(text[match])), value > 0 else { continue }
            let after = String(text[match.upperBound...].prefix(5))
            let before = String(text[..<match.lowerBound].suffix(3))
            return (value, currencyToken(in: after) ?? currencyToken(in: before))
        }
        return nil
    }

    private static func currencyToken(in text: String) -> Currency? {
        for (currency, pattern) in currencyPatterns where text.range(of: pattern, options: .regularExpression) != nil {
            return currency
        }
        return nil
    }

    /// Para birimi işaretleri; harf kısaltmaları kelime olarak ("try" ≠ "country").
    private static let currencyPatterns: [(Currency, String)] = [
        (.TRY, #"(?<![a-z])(tl|try)(?![a-z])|₺"#),
        (.USD, #"(?<![a-z])usd(?![a-z])|\$"#),
        (.EUR, #"(?<![a-z])(eur|euro)(?![a-z])|€"#),
    ]

    private static func integer(after labels: [String], excluding: [String], in lines: [String]) -> Int? {
        for text in values(after: labels, excluding: excluding, in: lines) {
            let cleaned = text
                .replacingOccurrences(of: numericDatePattern, with: " ", options: .regularExpression)
                .replacingOccurrences(of: amountPattern, with: " ", options: .regularExpression)
            if let match = cleaned.range(of: #"\b\d{1,3}\b"#, options: .regularExpression),
               let value = Int(cleaned[match]), (1...PaymentDraft.maxInstallments).contains(value) {
                return value
            }
        }
        return nil
    }

    private static func date(after labels: [String], in lines: [String]) -> YearMonth? {
        values(after: labels, in: lines).lazy.compactMap(firstDate(in:)).first
    }

    // ICU (NSRegularExpression): Swift `Regex` lookbehind desteklemiyor. Desenler sabit; bir kez derlenir.
    private static let numericDateRegex = try! NSRegularExpression(pattern: numericDatePattern)
    private static let namedDateRegex = try! NSRegularExpression(
        pattern: #"\d{1,2} ("# + monthNames.joined(separator: "|") + #") (\d{4})"#)
    private static let planRowRegex = try! NSRegularExpression(
        pattern: #"^(\d{1,3}) +(\d{1,2}[./-]\d{1,2}[./-]\d{4}) +(.*)$"#)
    private static let amountRegex = try! NSRegularExpression(pattern: amountPattern)

    /// Eşleşmenin gruplarını metin olarak döner; eşleşme yoksa nil.
    private static func groups(_ regex: NSRegularExpression, in text: String) -> [String]? {
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }

    /// "15.01.2026", "15/01/2026", "15 ocak 2026".
    private static func firstDate(in text: String) -> YearMonth? {
        if let g = groups(numericDateRegex, in: text), let month = Int(g[2]), let year = Int(g[3]),
           (1...12).contains(month) {
            return YearMonth(year: year, month: month)
        }
        if let g = groups(namedDateRegex, in: text), let year = Int(g[2]),
           let index = monthNames.firstIndex(of: g[1]) {
            return YearMonth(year: year, month: index + 1)
        }
        return nil
    }

    /// "1 05/03/2026 2.150,00 1.700,00 …" satırlarından oluşan ödeme planı.
    /// Taksit sütunu: satırların çoğunda aynı kalan sütunlar içinde değeri en büyük olan
    /// (sabit BSMV/masraf sütunundan büyük, her satırda değişen kalan anapara sütunundan farklı).
    private static func paymentPlan(in lines: [String]) -> (count: Int, first: YearMonth, monthly: Decimal)? {
        var rows: [(number: Int, month: YearMonth, amounts: [Decimal])] = []
        for line in lines {
            guard let g = groups(planRowRegex, in: line), let number = Int(g[1]),
                  let month = firstDate(in: g[2]) else { continue }
            let rest = g[3] as NSString
            let amounts = amountRegex.matches(in: g[3], range: NSRange(location: 0, length: rest.length))
                .compactMap { AmountParser.parse(rest.substring(with: $0.range)) }
            guard !amounts.isEmpty else { continue }
            rows.append((number, month, amounts))
        }
        guard rows.count >= 2, let start = rows.min(by: { $0.number < $1.number }),
              let count = rows.map(\.number).max(),
              let columns = rows.map(\.amounts.count).min() else { return nil }

        var best: (value: Decimal, frequency: Int)?
        for column in 0..<columns {
            var frequency: [Decimal: Int] = [:]
            for row in rows { frequency[row.amounts[column], default: 0] += 1 }
            // En sık değer; eşitlikte ilk satırınki.
            guard let mode = rows.map({ $0.amounts[column] }).max(by: { frequency[$0]! < frequency[$1]! }),
                  frequency[mode]! * 2 >= rows.count else { continue }
            if best == nil || mode > best!.value { best = (mode, frequency[mode]!) }
        }
        let monthly = best?.value ?? start.amounts[0]
        return (count, start.month.adding(months: -(start.number - 1)), monthly)
    }

    /// Belgede en çok geçen para birimi; yabancı para TL'den açıkça fazla değilse TL.
    private static func currency(in lines: [String]) -> Currency {
        let text = lines.joined(separator: "\n")
        func count(_ currency: Currency) -> Int {
            guard let pattern = currencyPatterns.first(where: { $0.0 == currency })?.1,
                  let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
            return regex.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
        }
        let tl = count(.TRY), usd = count(.USD), eur = count(.EUR)
        if usd > tl * 2, usd >= eur { return .USD }
        if eur > tl * 2 { return .EUR }
        return .TRY
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }
}
