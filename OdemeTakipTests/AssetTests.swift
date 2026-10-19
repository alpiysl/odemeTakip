import Foundation
import SwiftData
import Testing
@testable import OdemeTakip

@MainActor
struct AssetTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(for: Payment.self, CashPayment.self, Asset.self, AssetMovement.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
    }

    private func goldDraft(_ amount: String = "20") -> AssetDraft {
        var d = AssetDraft()
        d.name = " Altın "
        d.unit = .gram
        d.amountText = amount
        return d
    }

    @Test func draftValidation() {
        var d = AssetDraft()
        #expect(d.validationMessage == "Ad gerekli")
        d.name = "Dolar"
        #expect(d.validationMessage == "Geçerli bir miktar gir")
        d.amountText = "1500,"
        #expect(d.visibleValidationMessage == nil)
        d.amountText = "1.500"
        #expect(d.isValid)
        d.isEditing = true
        d.amountText = ""
        #expect(d.isValid)
    }

    @Test func defaultIconsFollowUnit() {
        #expect(AssetDraft.defaultIcon(for: .gram) == "🪙")
        #expect(AssetDraft.defaultIcon(for: .resat) == "🪙")
        #expect(AssetDraft.defaultIcon(for: .USD) == "💵")
        #expect(AssetDraft.defaultIcon(for: .EUR) == "💶")
        #expect(AssetDraft.defaultIcon(for: .TRY) == "🏦")
    }

    @Test func createWithInitialMovement() throws {
        let asset = try #require(Asset.make(from: goldDraft(), in: context))
        try context.save()
        #expect(asset.name == "Altın")
        #expect(asset.unit == .gram)
        #expect(asset.quantity == 20)
        #expect(asset.sortedMovements.count == 1)
        #expect(asset.snapshot == AssetSnapshot(id: asset.id, unit: .gram, quantity: 20))
    }

    @Test func addAndWithdrawMovements() throws {
        let asset = try #require(Asset.make(from: goldDraft(), in: context))
        asset.addMovement(amount: 5, date: .now)
        asset.addMovement(amount: -8, date: .now.addingTimeInterval(60))
        try context.save()
        #expect(asset.quantity == 17)
        #expect(asset.sortedMovements.first?.amount == -8)
    }

    @Test func removingDepositCannotMakeQuantityNegative() throws {
        let asset = try #require(Asset.make(from: goldDraft("10"), in: context))
        asset.addMovement(amount: -8, date: .now.addingTimeInterval(60))
        try context.save()
        let deposit = try #require(asset.sortedMovements.last)
        #expect(deposit.amount == 10)
        #expect(!asset.canRemove(deposit))
        #expect(!asset.removeMovement(deposit))
        let withdrawal = try #require(asset.sortedMovements.first)
        #expect(asset.removeMovement(withdrawal))
        try context.save()
        #expect(asset.quantity == 10)
    }

    @Test func movementDraftLimitsWithdrawal() {
        var d = MovementDraft(available: 17, unit: .gram, isWithdrawal: true)
        d.amountText = "20"
        #expect(d.amount == nil)
        #expect(d.validationMessage == "Mevcut miktardan (17 gr) fazla çıkarılamaz")
        d.amountText = "17"
        #expect(d.signedAmount == -17)
        var deposit = MovementDraft(available: 0, unit: .USD, isWithdrawal: false)
        deposit.amountText = "250"
        #expect(deposit.signedAmount == 250)
        deposit.amountText = "0"
        #expect(deposit.validationMessage == "Geçerli bir miktar gir")
    }

    @Test func editKeepsUnitAndMovements() throws {
        let asset = try #require(Asset.make(from: goldDraft(), in: context))
        var d = asset.makeDraft()
        #expect(d.isEditing)
        d.name = "Yastık altı"
        d.icon = "🐷"
        d.unit = .USD
        #expect(asset.apply(d))
        #expect(asset.name == "Yastık altı")
        #expect(asset.unit == .gram)
        #expect(asset.quantity == 20)
    }

    @Test func deletingAssetCascades() throws {
        let asset = try #require(Asset.make(from: goldDraft(), in: context))
        try context.save()
        #expect(asset.isLive)
        context.delete(asset)
        try context.save()
        #expect(!asset.isLive)
        #expect(try context.fetchCount(FetchDescriptor<AssetMovement>()) == 0)
    }
}
