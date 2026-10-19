import Foundation
import Testing
@testable import OdemeTakip

struct PaymentDraftTests {
    private func creditDraft() -> PaymentDraft {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 2))
        d.kind = .credit
        d.name = "  Araç Kredisi "
        d.installmentCountText = "16"
        d.monthlyAmountText = "7.500"
        d.prepaidCountText = "8"
        return d
    }

    @Test func validCreditDraftBuildsPreview() {
        let d = creditDraft()
        #expect(d.isValid)
        #expect(d.trimmedName == "Araç Kredisi")
        let preview = d.preview
        #expect(preview.map(PaymentCalculator.total) == 120_000)
        #expect(preview.map(PaymentCalculator.remaining) == 60_000)
        #expect(preview.flatMap(PaymentCalculator.lastInstallmentMonth) == YearMonth(year: 2027, month: 5))
    }

    @Test func emptyPrepaidMeansZero() {
        var d = creditDraft()
        d.prepaidCountText = ""
        #expect(d.prepaidCount == 0)
        #expect(d.isValid)
    }

    @Test func creditValidationMessages() {
        var d = creditDraft()
        d.name = "   "
        #expect(d.validationMessage == "Ad gerekli")

        d = creditDraft(); d.installmentCountText = "0"
        #expect(d.validationMessage == "Taksit sayısı 1–480 arası olmalı")
        d.installmentCountText = "481"
        #expect(!d.isValid)

        d = creditDraft(); d.monthlyAmountText = "0"
        #expect(d.validationMessage == "Geçerli bir aylık tutar gir")
        d.monthlyAmountText = "abc"
        #expect(!d.isValid)

        d = creditDraft(); d.prepaidCountText = "17"
        #expect(d.validationMessage == "Önceden ödenen taksit 0–16 arası olmalı")
    }

    @Test func editingCannotDropBelowPaidInstallments() {
        var d = creditDraft()
        d.isEditing = true
        d.minimumInstallmentCount = 10
        d.installmentCountText = "9"
        #expect(d.validationMessage == "Taksit sayısı ödenmiş taksitlerden (10) az olamaz")
        d.installmentCountText = "10"
        #expect(d.isValid)
        #expect(d.prepaidCount == 0)
        #expect(d.preview == nil)
    }

    @Test func cashDraftValidation() {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .cash
        d.name = "Ahmet"
        d.totalDebtText = ""
        #expect(d.validationMessage == "Geçerli bir toplam borç gir")
        d.totalDebtText = "80.000"
        #expect(d.isValid)
        #expect(d.totalDebt == 80_000)
    }

    @Test func editingCashCannotDropBelowPaid() {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .cash
        d.name = "Ahmet"
        d.isEditing = true
        d.minimumTotalDebt = 30_000
        d.totalDebtText = "20000"
        #expect(d.validationMessage == "Toplam borç ödenen tutardan (₺30.000) az olamaz")
    }

    @Test func hasInputDetectsTyping() {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        #expect(!d.hasInput)
        d.monthlyAmountText = "5"
        #expect(d.hasInput)
    }

    @Test func cashPaymentCannotExceedRemaining() {
        var d = CashPaymentDraft(remaining: 50_000, currency: .TRY)
        #expect(d.amount == nil)
        #expect(d.validationMessage == nil)
        d.amountText = "60.000"
        #expect(d.amount == nil)
        #expect(d.validationMessage == "Kalan borçtan (₺50.000) fazla olamaz")
        d.amountText = "0"
        #expect(d.validationMessage == "Geçerli bir tutar gir")
        d.amountText = "50.000"
        #expect(d.amount == 50_000)
        #expect(d.validationMessage == nil)
    }

    @Test func trailingDecimalSeparatorHidesWarningWhileTyping() {
        var d = creditDraft()
        d.monthlyAmountText = "1500,"
        #expect(!d.isValid)
        #expect(d.visibleValidationMessage == nil)
        d.monthlyAmountText = "abc"
        #expect(d.visibleValidationMessage == "Geçerli bir aylık tutar gir")

        var cash = CashPaymentDraft(remaining: 50_000, currency: .TRY)
        cash.amountText = "1500,"
        #expect(cash.amount == nil)
        #expect(cash.validationMessage == nil)
    }

    @Test func receivableDraftValidation() {
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .receivable
        d.name = "Mehmet"
        #expect(d.validationMessage == "Geçerli bir toplam alacak gir")
        d.totalDebtText = "3"
        d.currency = .ceyrek
        #expect(d.isValid)
        d.isEditing = true
        d.minimumTotalDebt = 5
        #expect(d.validationMessage == "Toplam alacak tahsil edilenden (5 çeyrek) az olamaz")
        #expect(PaymentDraft.defaultIcon(for: .receivable) == "💰")
        #expect(PaymentKind.receivable.title == "Alacak")
    }

    @Test func receivableCollectionMessageMentionsReceivable() {
        var d = CashPaymentDraft(remaining: 4, currency: .ceyrek, isReceivable: true)
        d.amountText = "5"
        #expect(d.validationMessage == "Kalan alacaktan (4 çeyrek) fazla olamaz")
    }

    @Test func debtFormOffersGoldUnits() {
        #expect(PaymentDraft.currencyOptions == Currency.allCases)
        var d = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        d.kind = .cash
        d.name = "Kuyumcu"
        d.currency = .yarim
        d.totalDebtText = "3"
        #expect(d.isValid)
    }
}
