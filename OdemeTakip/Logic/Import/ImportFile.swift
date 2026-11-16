import Foundation

/// İçe aktarılan PDF'in okunacak geçici kopyası.
enum ImportFile {
    /// Dosyayı geçici klasöre kopyalar. Dosyalar uygulamasından gelen adres güvenlik kapsamlıdır.
    /// "Birlikte aç" ile gelen dosyayı iOS `Documents/Inbox` içine koyar; kişisel bilgi içeren ekstre
    /// uygulamada ve yedeklerde kalmasın diye oradaki kopya silinir.
    static func copyToTemporary(_ url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let directory = FileManager.default.temporaryDirectory.appending(path: "Imports")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(path: UUID().uuidString + ".pdf")
        try FileManager.default.copyItem(at: url, to: destination)
        if isInInbox(url) { try? FileManager.default.removeItem(at: url) }
        return destination
    }

    private static func isInInbox(_ url: URL) -> Bool {
        let inbox = URL.documentsDirectory.appending(path: "Inbox").standardizedFileURL.resolvingSymlinksInPath().path()
        return url.standardizedFileURL.resolvingSymlinksInPath().path().hasPrefix(inbox)
    }
}
