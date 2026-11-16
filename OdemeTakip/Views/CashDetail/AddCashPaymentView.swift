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
                    LabeledContent(L10n.Common.amount) {
                        TextField("0", text: $draft.amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($amountFocused)
                    }
                    Button {
                        draft.amountText = AmountParser.editingText(draft.remaining)
                    } label: {
                        Label(draft.isReceivable ? L10n.Debt.payAllReceivable : L10n.Debt.payAllDebt,
                              systemImage: "equal.circle")
                    }
                    DatePicker(L10n.Common.date, selection: $draft.date, displayedComponents: .date)
                        .onChange(of: draft.date) { amountFocused = false }
                        .environment(\.locale, L10n.locale)
                } footer: {
                    if let message = draft.validationMessage {
                        Text(message).foregroundStyle(Theme.cash)
                    } else {
                        Text(remainingFooter)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(draft.isReceivable ? L10n.Debt.addCollectionTitle : L10n.Debt.addPaymentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) { save() }
                        .fontWeight(.bold)
                        .disabled(draft.amount == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { amountFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { amountFocused = true }
        }
        .tint(Theme.accent)
        .appColorScheme()
        .presentationDetents([.medium, .large])
    }

    /// "Kalan: $2.400 (≈ ₺96.000)"
    private var remainingFooter: String {
        let remaining = MoneyFormatter.string(draft.remaining, draft.currency)
        guard let lira = FooterTotalsView.Line.liraEquivalent(draft.remaining, draft.currency, rates: rates) else {
            return L10n.Debt.remainingFooter(remaining)
        }
        return L10n.Debt.remainingFooter(remaining, lira: lira.value)
    }

    private func save() {
        guard let amount = draft.amount else { return }
        payment.addCashPayment(amount: amount, date: draft.date)
        context.saveQuietly()
        dismiss()
    }
}
