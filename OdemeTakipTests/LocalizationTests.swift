import Foundation
import Testing
@testable import OdemeTakip

/// `L10n+<Tablo>.swift` erişimcileri ile `Resources/Strings/<Tablo>.xcstrings` katalogları birbirini tutmalı.
struct LocalizationTests {
    private static let appDir = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "OdemeTakip")

    private static func catalogKeys(_ table: String) throws -> Set<String> {
        let url = appDir.appending(path: "Resources/Strings/\(table).xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return Set((json?["strings"] as? [String: Any] ?? [:]).keys)
    }

    /// Erişim dosyalarındaki `s("anahtar"` çağrıları, tablo adına göre.
    private static func usedKeys() throws -> [String: Set<String>] {
        let dir = appDir.appending(path: "Localization")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let regex = try Regex(#"s\("([^"]+)""#)
        var result: [String: Set<String>] = [:]
        for file in files where file.lastPathComponent.hasPrefix("L10n+") {
            let table = String(file.deletingPathExtension().lastPathComponent.dropFirst("L10n+".count))
            let source = try String(contentsOf: file, encoding: .utf8)
            result[table] = Set(source.matches(of: regex).compactMap { $0.output[1].substring.map(String.init) })
        }
        return result
    }

    @Test func everyAccessorKeyExistsInItsCatalog() throws {
        let used = try Self.usedKeys()
        #expect(!used.isEmpty)
        for (table, keys) in used {
            let missing = keys.subtracting(try Self.catalogKeys(table))
            #expect(missing.isEmpty, "\(table).xcstrings eksik: \(missing.sorted())")
        }
    }

    @Test func catalogsHaveNoUnusedKeys() throws {
        for (table, keys) in try Self.usedKeys() {
            let unused = try Self.catalogKeys(table).subtracting(keys)
            #expect(unused.isEmpty, "\(table).xcstrings kullanılmayan: \(unused.sorted())")
        }
    }

    @Test func bundleResolvesStrings() {
        #expect(L10n.Common.cancel == "İptal")
        #expect(L10n.Common.approx("₺96.000") == "≈ ₺96.000")
    }
}
