import Foundation

/// Paylaşılabilir dekont kartının metinleri. Görünümden bağımsız, test edilebilir.
struct Receipt: Equatable, Sendable {
    var headline: String
    var title: String
    var icon: String
    var kind: PaymentKind
    var amountText: String
    var dateText: String
    /// Taksitlerde "Taksit 3/12".
    var detailText: String?
    var remainingTitle: String
    var remainingText: String
    /// 0…1
    var progress: Double
    var fileName: String

    /// Elden ödeme ya da alacak tahsilatı.
    static func cashPayment(amount: Decimal, date: Date, snapshot: PaymentSnapshot,
                            name: String, icon: String, paidThrough: Decimal? = nil,
                            calendar: Calendar = AppCalendar.calendar) -> Receipt {
        let year = calendar.component(.year, from: date)
        let receivable = snapshot.kind == .receivable
        // Kalan, bu ödemeden hemen sonraki durum; bugünkü değil.
        var snapshot = snapshot
        if let paidThrough { snapshot.cashPaid = paidThrough }
        return Receipt(
            headline: receivable ? L10n.Documents.collectionDone : L10n.Documents.paymentDone,
            title: name, icon: icon, kind: snapshot.kind,
            amountText: MoneyFormatter.string(amount, snapshot.currency),
            dateText: L10n.Documents.fullDate(TurkishMonths.dayMonth(date, calendar: calendar), year),
            detailText: nil,
            remainingTitle: receivable ? L10n.Documents.remainingReceivable : L10n.Documents.remaining,
            remainingText: remainingText(snapshot),
            progress: PaymentCalculator.progress(snapshot),
            fileName: fileName(name: name, date: date, calendar: calendar))
    }

    /// Ödenmiş kredi taksiti; ödenmemiş ya da aralık dışıysa nil.
    static func installment(index: Int, snapshot: PaymentSnapshot, name: String, icon: String,
                            calendar: Calendar = AppCalendar.calendar) -> Receipt? {
        guard snapshot.kind == .credit, (0..<snapshot.installmentCount).contains(index),
              snapshot.paidInstallments.contains(index) else { return nil }
        let month = PaymentCalculator.installmentMonth(snapshot, index: index)
        // Kalan, bu taksit ödendiğindeki durum: sonraki taksitler sayılmaz.
        var snapshot = snapshot
        snapshot.paidInstallments = snapshot.paidInstallments.filter { $0 <= index }
        return Receipt(
            headline: L10n.Documents.installmentDone,
            title: name, icon: icon, kind: .credit,
            amountText: MoneyFormatter.string(snapshot.monthlyAmount, snapshot.currency),
            dateText: month.longLabel,
            detailText: L10n.Documents.installmentOf(index + 1, snapshot.installmentCount),
            remainingTitle: L10n.Documents.remaining,
            remainingText: remainingText(snapshot),
            progress: PaymentCalculator.progress(snapshot),
            fileName: fileName(name: name, date: month.firstDay(calendar: calendar), calendar: calendar))
    }

    private static func remainingText(_ snapshot: PaymentSnapshot) -> String {
        PaymentCalculator.isCompleted(snapshot)
            ? L10n.Documents.completed
            : MoneyFormatter.string(PaymentCalculator.remaining(snapshot), snapshot.currency)
    }

    static let maxNameLength = 60

    /// "Dekont-Ev-Kira-2026-10-20.png": dosya sistemine ve mesajlaşma uygulamalarına uygun.
    static func fileName(name: String, date: Date, calendar: Calendar = AppCalendar.calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let stamp = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        // Uzun adlar mesajlaşma uygulamalarında kesilir; ad kısmı en çok 60 karakter.
        var title = words.joined(separator: "-")
        if title.count > maxNameLength {
            title = String(title.prefix(maxNameLength)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        let parts = [L10n.Documents.fileNamePrefix] + (title.isEmpty ? [] : [title]) + [stamp]
        return parts.joined(separator: "-") + ".png"
    }
}

extension Receipt {
    /// Kaydın tüm ödeme dekontları, kimliğe göre. Kalanlar tek geçişte, eskiden yeniye biriken toplamla.
    static func all(in payment: Payment) -> [UUID: Receipt] {
        let snapshot = payment.snapshot
        var paidThrough: Decimal = 0
        var result: [UUID: Receipt] = [:]
        for entry in payment.sortedCashPayments.reversed() {
            paidThrough += entry.amount
            result[entry.id] = cashPayment(amount: entry.amount, date: entry.date, snapshot: snapshot,
                                           name: payment.name, icon: payment.icon, paidThrough: paidThrough)
        }
        return result
    }

    static func make(installment index: Int, in payment: Payment) -> Receipt? {
        installment(index: index, snapshot: payment.snapshot, name: payment.name, icon: payment.icon)
    }
}
