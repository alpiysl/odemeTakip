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
        result.currency = currency(in: lines)

        var monthly = amount(after: Labels.monthly, in: lines)
        var count = integer(after: Labels.count, excluding: Labels.countExclusions, in: lines)
        var first = date(after: Labels.firstDate, in: lines)
        let explicitPaid = integer(after: Labels.paid, excluding: [], in: lines)
        let repayment = amount(after: Labels.totalRepayment, in: lines)

        if let plan = paymentPlan(in: lines) {
            count = count ?? plan.count
            first = first ?? plan.first
            monthly = monthly ?? plan.monthly
        }
        if monthly == nil, let repayment, let count, count > 0 {
            monthly = rounded(repayment / Decimal(count))
        }

        if monthly != nil || count != nil {
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
        static let count = ["taksit sayisi", "vade sayisi", "toplam taksit", "vade suresi", "kredi vadesi", "vade (ay)", "vade"]
        static let countExclusions = ["odenen", "odenmis", "kalan", "tarihi"]
        static let paid = ["odenen taksit sayisi", "odenmis taksit sayisi", "odenen taksit"]
        static let firstDate = ["ilk taksit tarihi", "ilk taksit odeme tarihi", "ilk odeme tarihi"]
        static let totalRepayment = ["toplam geri odeme", "geri odenecek toplam", "toplam odeme tutari"]
        static let cardDebt = ["donem borcu", "hesap ozeti borcu", "toplam borc"]
    }

    private static let amountPattern = #"\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2}"#
    private static let numericDatePattern = #"(\d{1,2})[./-](\d{1,2})[./-](\d{4})"#
    private static let monthNames = ["ocak", "subat", "mart", "nisan", "mayis", "haziran",
                                     "temmuz", "agustos", "eylul", "ekim", "kasim", "aralik"]

    // MARK: Değer bulma

    /// Etiketten sonraki metin; etiket satırda yalnızsa bir sonraki satır.
    private static func values(after labels: [String], excluding: [String] = [], in lines: [String]) -> [String] {
        var found: [String] = []
        for label in labels {
            for (index, line) in lines.enumerated() {
                guard let range = line.range(of: label),
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

    private static func amount(after labels: [String], in lines: [String]) -> Decimal? {
        for text in values(after: labels, in: lines) {
            if let match = text.range(of: amountPattern, options: .regularExpression),
               let value = AmountParser.parse(String(text[match])), value > 0 {
                return value
            }
        }
        return nil
    }

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

    /// "15.01.2026", "15/01/2026", "15 ocak 2026".
    private static func firstDate(in text: String) -> YearMonth? {
        if let match = text.firstMatch(of: try! Regex(numericDatePattern)),
           let month = match.output[2].substring.flatMap({ Int($0) }),
           let year = match.output[3].substring.flatMap({ Int($0) }), (1...12).contains(month) {
            return YearMonth(year: year, month: month)
        }
        let names = monthNames.joined(separator: "|")
        if let match = text.firstMatch(of: try! Regex(#"\d{1,2} ("# + names + #") (\d{4})"#)),
           let name = match.output[1].substring.map(String.init),
           let year = match.output[2].substring.flatMap({ Int($0) }),
           let index = monthNames.firstIndex(of: name) {
            return YearMonth(year: year, month: index + 1)
        }
        return nil
    }

    /// "1 05/03/2026 2.150,00 …" satırlarından oluşan ödeme planı.
    private static func paymentPlan(in lines: [String]) -> (count: Int, first: YearMonth, monthly: Decimal)? {
        let regex = try! Regex(#"^(\d{1,3}) +(\d{1,2}[./-]\d{1,2}[./-]\d{4}) +("# + amountPattern + ")")
        var rows: [(number: Int, month: YearMonth, amount: Decimal)] = []
        for line in lines {
            guard let match = line.firstMatch(of: regex),
                  let number = match.output[1].substring.flatMap({ Int($0) }),
                  let month = match.output[2].substring.flatMap({ firstDate(in: String($0)) }),
                  let amount = match.output[3].substring.flatMap({ AmountParser.parse(String($0)) }) else { continue }
            rows.append((number, month, amount))
        }
        guard rows.count >= 2, let start = rows.min(by: { $0.number < $1.number }),
              let count = rows.map(\.number).max() else { return nil }
        var frequency: [Decimal: Int] = [:]
        for row in rows { frequency[row.amount, default: 0] += 1 }
        // En sık tutar; eşitlikte ilk satırınki (`max(by:)` eşitlikte ilkini tutar).
        let monthly = rows.max { frequency[$0.amount, default: 0] < frequency[$1.amount, default: 0] }?.amount ?? start.amount
        return (count, start.month.adding(months: -(start.number - 1)), monthly)
    }

    private static func currency(in lines: [String]) -> Currency {
        let text = " " + lines.joined(separator: " ") + " "
        func count(_ tokens: [String]) -> Int {
            tokens.reduce(0) { $0 + text.components(separatedBy: $1).count - 1 }
        }
        let tl = count([" tl", "try", "₺"])
        let usd = count(["usd", "$"])
        let eur = count(["eur", "€"])
        if usd > tl, usd >= eur { return .USD }
        if eur > tl { return .EUR }
        return .TRY
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }
}
