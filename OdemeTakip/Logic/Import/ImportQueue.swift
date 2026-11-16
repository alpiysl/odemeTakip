import Foundation

/// PDF içe aktarma sırası: aynı anda tek içe aktarma. Meşgulken gelen dosya bekletilir
/// (en son gelen geçerli); açık form kapanınca ya da okuma bitince sıradaki başlar.
struct ImportQueue {
    private(set) var isBusy = false
    private var pending: URL?

    /// Hemen başlatılacaksa adresi döner; meşgulse bekletir ve nil döner.
    mutating func request(_ url: URL) -> URL? {
        guard !isBusy else {
            pending = url
            return nil
        }
        isBusy = true
        return url
    }

    /// Mevcut içe aktarma bitti; sırada dosya varsa onu döner (meşgul kalır).
    mutating func finished() -> URL? {
        if let next = pending {
            pending = nil
            return next
        }
        isBusy = false
        return nil
    }
}
