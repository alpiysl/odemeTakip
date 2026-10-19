import SwiftData
import SwiftUI

struct AssetDetailView: View {
    let asset: Asset
    let rates: ExchangeRates?

    private enum MovementSheet: String, Identifiable {
        case deposit, withdrawal
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var sheet: MovementSheet?
    @State private var editing = false
    @State private var deleteRequested = false

    var body: some View {
        if !asset.isLive {
            Theme.background.ignoresSafeArea()
        } else {
            content
        }
    }

    private var content: some View {
        let snapshot = asset.snapshot
        let movements = asset.sortedMovements
        let lira = CurrencyConverter.toTRY([snapshot.unit: snapshot.quantity], rates: rates)

        return List {
            Section {
                Text(priceText(snapshot.unit))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Color.clear)

                HStack(spacing: 10) {
                    actionButton("+ Ekle", filled: true) { sheet = .deposit }
                    actionButton("− Çıkar", filled: false) { sheet = .withdrawal }
                        .disabled(snapshot.quantity <= 0)
                        .opacity(snapshot.quantity <= 0 ? 0.4 : 1)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                if movements.isEmpty {
                    Text("Henüz hareket yok")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .listRowBackground(Color.clear)
                }
                ForEach(movements) { movement in
                    HStack(spacing: 12) {
                        Image(systemName: movement.amount >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                            .foregroundStyle(movement.amount >= 0 ? Theme.paid : Color(hex: 0xFF6961))
                        Text(YearMonth(date: movement.date).longLabel)
                        Text("· \(TurkishMonths.dayMonth(movement.date))")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Text((movement.amount >= 0 ? "+" : "−") + MoneyFormatter.string(abs(movement.amount), snapshot.unit))
                            .monospacedDigit()
                            .foregroundStyle(movement.amount >= 0 ? Theme.paid : Color(hex: 0xFF6961))
                    }
                    .font(.subheadline)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.divider)
                    .deleteDisabled(!asset.canRemove(movement))
                }
                .onDelete { offsets in
                    for index in offsets { asset.removeMovement(movements[index]) }
                    context.saveQuietly()
                }
            } header: {
                Text("Hareketler").font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FooterTotalsView(
                lines: [.init(title: "Miktar", value: MoneyFormatter.string(snapshot.quantity, snapshot.unit))],
                resultTitle: "TL değeri",
                resultValue: lira.map { MoneyFormatter.string($0, .TRY) } ?? "Kur bekleniyor")
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("\(asset.icon) \(asset.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button("Düzenle") { editing = true }
        }
        .sheet(item: $sheet) { kind in
            AddMovementView(asset: asset, isWithdrawal: kind == .withdrawal)
        }
        .sheet(isPresented: $editing, onDismiss: handleSheetDismiss) {
            AssetFormView(mode: .edit(asset), onDeleteRequested: { deleteRequested = true })
        }
    }

    private func priceText(_ unit: Currency) -> String {
        guard unit != .TRY else { return "Türk lirası birikim" }
        let one = MoneyFormatter.string(1, unit)
        guard let price = rates?.rate(for: unit) else { return "\(one) — fiyat bekleniyor" }
        return "\(one) = \(MoneyFormatter.string(price, .TRY)) (satış)"
    }

    private func actionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if filled {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.savingsGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func handleSheetDismiss() {
        guard deleteRequested else { return }
        dismiss()
        PaymentDeletion.deleteAfterPop(asset, in: context)
    }
}

struct AddMovementView: View {
    let asset: Asset

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MovementDraft
    @FocusState private var amountFocused: Bool

    init(asset: Asset, isWithdrawal: Bool) {
        self.asset = asset
        _draft = State(initialValue: MovementDraft(available: asset.quantity, unit: asset.unit, isWithdrawal: isWithdrawal))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(draft.unit.isGold ? "Miktar (\(draft.unit.unitName))" : "Tutar") {
                        TextField("0", text: $draft.amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($amountFocused)
                    }
                    DatePicker("Tarih", selection: $draft.date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                        .onChange(of: draft.date) { amountFocused = false }
                } footer: {
                    if let message = draft.validationMessage {
                        Text(message).foregroundStyle(Theme.cash)
                    } else {
                        Text("Mevcut: \(MoneyFormatter.string(draft.available, draft.unit))")
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(draft.isWithdrawal ? "Çıkar" : "Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .disabled(draft.signedAmount == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Bitti") { amountFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { amountFocused = true }
        }
        .tint(Theme.paid)
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }

    private func save() {
        guard let amount = draft.signedAmount else { return }
        asset.addMovement(amount: amount, date: draft.date)
        context.saveQuietly()
        dismiss()
    }
}
