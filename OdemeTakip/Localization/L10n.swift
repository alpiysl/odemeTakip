import Foundation

/// Arayüz metinleri kodda değil, `Resources/Strings/<Tablo>.xcstrings` dosyalarında durur.
/// Her tablo için `L10n+<Tablo>.swift` tipli erişim sağlar: `L10n.Common.cancel`, `L10n.Debt.paidOf(3, 12)`.
enum L10n {
    /// Sayı ve tarih biçimleri uygulama genelinde Türkçe.
    static let locale = Locale(identifier: "tr_TR")

    /// Tablodaki metni okur; `args` varsa `%@` / `%lld` yer tutucularını doldurur.
    /// Anahtar bulunamazsa anahtarın kendisi döner (testler bunu yakalar).
    static func string(_ key: String, table: String, args: [CVarArg] = []) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: nil, table: table)
        return args.isEmpty ? format : String(format: format, locale: locale, arguments: args)
    }
}
