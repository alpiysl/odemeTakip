import Foundation

/// Kredi ikonu olarak seçilebilen bankalar. Logo değil, banka rengiyle kısaltma rozeti çizilir.
/// Kayıtta ikon alanına `bank:<kimlik>` yazılır; emoji ikonlarla aynı alanı paylaşır.
enum Bank: String, CaseIterable, Identifiable {
    case isbank, garanti, akbank, qnb, halkbank, vakifbank, ziraat

    static let iconPrefix = "bank:"

    var id: String { rawValue }

    /// İkon alanına yazılan değer.
    var iconValue: String { Self.iconPrefix + rawValue }

    /// İkon alanı bir bankaysa o banka, değilse nil (emoji).
    init?(icon: String) {
        guard icon.hasPrefix(Self.iconPrefix) else { return nil }
        self.init(rawValue: String(icon.dropFirst(Self.iconPrefix.count)))
    }

    var name: String { L10n.Banks.name(self) }
    var monogram: String { L10n.Banks.monogram(self) }

    /// Rozet zemini (bankanın kurumsal rengine yakın).
    var backgroundHex: UInt32 {
        switch self {
        case .isbank: 0x0A3D91
        case .garanti: 0x1B8A4C
        case .akbank: 0xE30613
        case .qnb: 0x5C0632
        case .halkbank: 0x0060AE
        case .vakifbank: 0xFDB913
        case .ziraat: 0xB0101E
        }
    }

    /// Rozet yazı rengi.
    var foregroundHex: UInt32 {
        self == .vakifbank ? 0x1A1A1A : 0xFFFFFF
    }

    /// Belgede bankayı tanıtan ifadeler; `foldedForMatching` biçiminde (küçük harf, Türkçe harfsiz).
    var keywords: [String] {
        switch self {
        case .isbank: ["is bankasi", "isbank", "isbankasi"]
        case .garanti: ["garanti"]
        case .akbank: ["akbank", "axess"]
        case .qnb: ["qnb", "finansbank"]
        case .halkbank: ["halkbank", "halk bankasi"]
        case .vakifbank: ["vakifbank", "vakif bank", "vakiflar bankasi"]
        case .ziraat: ["ziraat"]
        }
    }

    /// Metinde en çok anılan banka; hiçbiri yoksa nil.
    static func detect(in text: String) -> Bank? {
        let folded = text.foldedForMatching
        let scores = allCases.map { bank in
            (bank, bank.keywords.reduce(0) { $0 + folded.components(separatedBy: $1).count - 1 })
        }
        guard let best = scores.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return scores.first { $0.1 == best.1 }?.0
    }
}

extension String {
    /// Eşleştirme için: Türkçe küçük harf, aksansız (ş→s, ı→i, ğ→g…), bölünmez boşluk → boşluk.
    /// OCR'ın Türkçe harfleri kaçırdığı metinlerle aynı biçime getirir.
    var foldedForMatching: String {
        lowercased(with: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
    }
}
