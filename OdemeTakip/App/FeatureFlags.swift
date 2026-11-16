import Foundation

/// Sürüme göre açılıp kapanan özellikler. Derleme anında sabittir; uzaktan açılmaz.
enum FeatureFlags {
    /// Banka PDF'inden borç ekleme — 1.2'de açılacak.
    /// Release'de kapalı. DEBUG'da UI testleri `-enablePDFImport` argümanıyla açar.
    static var pdfImport: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-enablePDFImport")
        #else
        false
        #endif
    }
}
