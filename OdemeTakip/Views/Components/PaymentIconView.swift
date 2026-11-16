import SwiftUI

/// Kayıt ikonu: emoji ya da banka rozeti (banka renginde kısaltma).
struct PaymentIconView: View {
    let icon: String
    var size: CGFloat = 40
    /// Emoji ikonların zemin rengi.
    var tint: Color = Theme.credit

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        if let bank = Bank(icon: icon) {
            Text(bank.monogram)
                .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, size * 0.08)
                .foregroundStyle(Color(hex: bank.foregroundHex))
                .frame(width: size, height: size)
                .background(Color(hex: bank.backgroundHex), in: shape)
                .accessibilityLabel(bank.name)
        } else {
            Text(icon)
                .font(.system(size: size * 0.5))
                .frame(width: size, height: size)
                .background(tint.opacity(0.14), in: shape)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Detay ekranı başlığı: küçük ikon/rozet + ad. Geri butonu ve VoiceOver için düz ad da verilir.
    func recordTitle(icon: String, name: String) -> some View {
        navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        PaymentIconView(icon: icon, size: 26, tint: .clear)
                        Text(name).font(.headline).lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
    }
}

/// Formlarda ikon seçimi: önce bankalar (sadece kredide), sonra emojiler.
struct IconGridPicker: View {
    @Binding var selection: String
    let emojis: [String]
    var showsBanks = false
    var tint: Color = Theme.credit

    private let columns = [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsBanks {
                caption(L10n.Banks.sectionBanks)
                grid(Bank.allCases.map(\.iconValue))
                caption(L10n.Banks.sectionOther)
            }
            grid(emojis)
        }
        .padding(.vertical, 6)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
    }

    private func grid(_ icons: [String]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    PaymentIconView(icon: icon, size: 44, tint: tint)
                        .overlay {
                            RoundedRectangle(cornerRadius: 44 * 0.3, style: .continuous)
                                .strokeBorder(selection == icon ? Theme.accent : .clear, lineWidth: 2.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Bank(icon: icon)?.name ?? icon)
                .accessibilityAddTraits(selection == icon ? .isSelected : [])
            }
        }
    }
}
