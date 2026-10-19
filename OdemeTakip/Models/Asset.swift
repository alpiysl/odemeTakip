import Foundation
import SwiftData

/// Birikim kalemi: tek birim (TL, döviz veya altın türü), miktar = hareketlerin toplamı.
@Model
final class Asset {
    var id = UUID()
    var name = ""
    var icon = "🏦"
    var unitRaw = Currency.TRY.rawValue
    var createdAt = Date.now
    @Relationship(deleteRule: .cascade, inverse: \AssetMovement.asset)
    var movements: [AssetMovement]? = []

    init(unit: Currency) {
        self.unitRaw = unit.rawValue
    }

    var unit: Currency {
        get { Currency(rawValue: unitRaw) ?? .TRY }
        set { unitRaw = newValue.rawValue }
    }

    var isLive: Bool { !isDeleted && modelContext != nil }

    private var liveMovements: [AssetMovement] {
        (movements ?? []).filter { !$0.isDeleted }
    }

    var sortedMovements: [AssetMovement] {
        liveMovements.sorted { $0.date > $1.date }
    }

    var quantity: Decimal {
        liveMovements.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var snapshot: AssetSnapshot {
        AssetSnapshot(id: id, unit: unit, quantity: quantity)
    }

    /// Geçerli taslaktan kaydı oluşturur, context'e ekler ve başlangıç hareketini yazar.
    static func make(from draft: AssetDraft, in context: ModelContext) -> Asset? {
        guard draft.isValid, let amount = draft.amount else { return nil }
        let asset = Asset(unit: draft.unit)
        asset.name = draft.trimmedName
        asset.icon = draft.icon
        context.insert(asset)
        asset.addMovement(amount: amount, date: .now)
        return asset
    }

    /// Düzenleme: ad ve ikon. Birim, hareketler bozulmasın diye değişmez.
    @discardableResult
    func apply(_ draft: AssetDraft) -> Bool {
        guard draft.isValid else { return false }
        name = draft.trimmedName
        icon = draft.icon
        return true
    }

    func makeDraft() -> AssetDraft {
        var draft = AssetDraft()
        draft.name = name
        draft.icon = icon
        draft.unit = unit
        draft.isEditing = true
        return draft
    }

    func addMovement(amount: Decimal, date: Date) {
        let movement = AssetMovement(amount: amount, date: date)
        modelContext?.insert(movement)
        movement.asset = self
    }

    /// Silindiğinde miktar eksiye düşmüyorsa true.
    func canRemove(_ movement: AssetMovement) -> Bool {
        quantity - movement.amount >= 0
    }

    @discardableResult
    func removeMovement(_ movement: AssetMovement) -> Bool {
        guard canRemove(movement) else { return false }
        modelContext?.delete(movement)
        return true
    }
}

@Model
final class AssetMovement {
    var id = UUID()
    /// İşaretli: + ekleme, − çıkarma.
    var amount: Decimal = 0
    var date = Date.now
    var asset: Asset?

    init(amount: Decimal, date: Date) {
        self.amount = amount
        self.date = date
    }
}
