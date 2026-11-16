import Foundation
import SwiftData
import UIKit
import Testing
@testable import OdemeTakip

struct ReceiptTests {
    private let oct20 = AppCalendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 14))!

    @Test func cashPaymentReceiptShowsAmountDateAndRemaining() {
        let snapshot = PaymentSnapshot.cash(debt: 1000, paid: 400, paymentCount: 2)
        let receipt = Receipt.cashPayment(amount: 250, date: oct20, snapshot: snapshot, name: "Ahmet", icon: "🤝")

        #expect(receipt.headline == "Ödeme yapıldı")
        #expect(receipt.title == "Ahmet")
        #expect(receipt.icon == "🤝")
        #expect(receipt.amountText == "₺250")
        #expect(receipt.dateText == "20 Eki 2026")
        #expect(receipt.detailText == nil)
        #expect(receipt.remainingTitle == "Kalan")
        #expect(receipt.remainingText == "₺600")
        #expect(abs(receipt.progress - 0.4) < 0.0001)
    }

    @Test func receivableReceiptUsesCollectionWording() {
        var snapshot = PaymentSnapshot.cash(debt: 500, paid: 100, paymentCount: 1)
        snapshot.kind = .receivable
        let receipt = Receipt.cashPayment(amount: 100, date: oct20, snapshot: snapshot, name: "Ayşe", icon: "💰")

        #expect(receipt.headline == "Tahsilat yapıldı")
        #expect(receipt.remainingTitle == "Kalan alacak")
        #expect(receipt.remainingText == "₺400")
    }

    @Test func installmentReceiptShowsMonthAndPosition() throws {
        let snapshot = PaymentSnapshot.credit(count: 12, monthly: 7500,
                                              first: YearMonth(year: 2026, month: 8), paid: [0, 1, 2])
        let receipt = try #require(Receipt.installment(index: 2, snapshot: snapshot, name: "Araç", icon: "🚗"))

        #expect(receipt.headline == "Taksit ödendi")
        #expect(receipt.amountText == "₺7.500")
        #expect(receipt.dateText == "Ekim 2026")
        #expect(receipt.detailText == "Taksit 3/12")
        #expect(receipt.remainingText == "₺67.500")
    }

    @Test(arguments: [3, -1, 12])
    func installmentReceiptRequiresPaidInstallmentInRange(index: Int) {
        let snapshot = PaymentSnapshot.credit(count: 12, monthly: 7500,
                                              first: YearMonth(year: 2026, month: 8), paid: [0, 1, 2])
        #expect(Receipt.installment(index: index, snapshot: snapshot, name: "Araç", icon: "🚗") == nil)
    }

    @Test func cashReceiptShowsBalanceRightAfterThatPayment() {
        let snapshot = PaymentSnapshot.cash(debt: 1000, paid: 700, paymentCount: 3)
        let receipt = Receipt.cashPayment(amount: 250, date: oct20, snapshot: snapshot, name: "Ahmet", icon: "🤝",
                                          paidThrough: 250)
        #expect(receipt.remainingText == "₺750")
        #expect(abs(receipt.progress - 0.25) < 0.0001)
    }

    @Test func installmentReceiptCountsOnlyInstallmentsUpToIt() throws {
        let snapshot = PaymentSnapshot.credit(count: 12, monthly: 7500,
                                              first: YearMonth(year: 2026, month: 8), paid: [0, 1, 2, 5])
        let receipt = try #require(Receipt.installment(index: 1, snapshot: snapshot, name: "Araç", icon: "🚗"))
        #expect(receipt.remainingText == "₺75.000")
    }

    @Test func completedDebtSaysCompleted() {
        let snapshot = PaymentSnapshot.cash(debt: 1000, paid: 1000, paymentCount: 3)
        let receipt = Receipt.cashPayment(amount: 300, date: oct20, snapshot: snapshot, name: "Ahmet", icon: "🤝")
        #expect(receipt.remainingText == "Tamamlandı")
    }

    @Test func longNamesAreCappedInFileName() {
        let name = String(repeating: "Çok uzun borç adı ", count: 10)
        let fileName = Receipt.fileName(name: name, date: oct20)
        #expect(fileName.count <= "Dekont-".count + 60 + "-2026-10-20.png".count)
        #expect(fileName.hasSuffix("-2026-10-20.png"))
    }

    @Test func fileNameIsSafeAndDated() {
        let snapshot = PaymentSnapshot.cash(debt: 1000)
        let receipt = Receipt.cashPayment(amount: 10, date: oct20, snapshot: snapshot, name: "Ev / Kira: Ekim", icon: "🏠")
        #expect(receipt.fileName == "Dekont-Ev-Kira-Ekim-2026-10-20.png")
    }
}

@MainActor
struct ReceiptImageTests {
    @Test func rendersPNGAtThreeTimesCardSize() throws {
        let receipt = Receipt.cashPayment(amount: 250, date: .now, snapshot: .cash(debt: 1000),
                                          name: "Ahmet", icon: "🤝")
        let data = try #require(ReceiptImage(receipt: receipt).pngData())
        let image = try #require(UIImage(data: data))
        let width = try #require(image.cgImage).width
        #expect(width == (360 + 32) * 3, "width \(width)")
    }
}

@MainActor
struct ReceiptBatchTests {
    @Test func allReceiptsCarryRunningBalanceInOnePass() throws {
        let container = try ModelContainer(for: Payment.self, CashPayment.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var draft = PaymentDraft(firstMonth: YearMonth(year: 2026, month: 10))
        draft.kind = .cash
        draft.name = "Ahmet"
        draft.totalDebtText = "1000"
        let payment = try #require(Payment.make(from: draft))
        container.mainContext.insert(payment)
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        payment.addCashPayment(amount: 100, date: base)
        payment.addCashPayment(amount: 200, date: base.addingTimeInterval(86_400))
        payment.addCashPayment(amount: 300, date: base.addingTimeInterval(2 * 86_400))

        let receipts = Receipt.all(in: payment)
        let ordered = payment.sortedCashPayments.reversed().map { receipts[$0.id]?.remainingText }
        #expect(ordered == ["₺900", "₺700", "₺400"])
    }
}
