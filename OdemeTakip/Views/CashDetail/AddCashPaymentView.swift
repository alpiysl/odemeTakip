import SwiftData
import SwiftUI

struct AddCashPaymentView: View {
    let payment: Payment

    @Environment(RateStore.self) private var rateStore
    private var rates: ExchangeRates? { rateStore.rates }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CashPaymentDraft
    @FocusState private var amountFocused: Bool

    init(payment: Payment) {
        self.payment = payment
        _draft = State(initialValue: CashPaymentDraft(
            remaining: PaymentCalculator.remaining(payment.snapshot),
            currency: payment.currency,
            isReceivable: payment.kind == .receivable))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Tutar") {
                        TextField("0", text: $draft.amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($amountFocused)
                    }
                    DatePicker("Tarih", selection: $draft.date, displayedComponents: .date)
                        .onChange(of: draft.date) { amountFocused = false }
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                } footer: {
                    if let message = draft.validationMessage {
                        Text(message).foregroundStyle(Theme.cash)
                    } else {
                        Text("Kalan: \(MoneyFormatter.string(draft.remaining, draft.currency))"
                             + (FooterTotalsView.Line.liraEquivalent(draft.remaining, draft.currency, rates: rates).map { " (\($0.value))" } ?? ""))
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(draft.isReceivable ? "Tahsilat ekle" : "Ödeme ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .disabled(draft.amount == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { amountFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { amountFocused = true }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let amount = draft.amount else { return }
        payment.addCashPayment(amount: amount, date: draft.date)
        context.saveQuietly()
        dismiss()
    }
}
