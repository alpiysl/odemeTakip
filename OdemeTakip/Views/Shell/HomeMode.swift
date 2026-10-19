import SwiftUI

/// Açılışta gösterilen ana ekran.
enum HomeMode: String, CaseIterable, Identifiable {
    case debt
    case savings

    static let storageKey = "homeMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debt: "Borç Takip"
        case .savings: "Birikim Takip"
        }
    }

    var shortTitle: String {
        switch self {
        case .debt: "Borç"
        case .savings: "Birikim"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .debt: Theme.gradient
        case .savings: Theme.savingsGradient
        }
    }
}

/// Başlık: uygulama adı + Borç | Birikim anahtarı.
struct HomeHeader: View {
    @Binding var mode: HomeMode

    var body: some View {
        HStack {
            Text("Varlık Takip").font(.headline.weight(.bold))
            Spacer()
            HStack(spacing: 0) {
                ForEach(HomeMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        Text(option.shortTitle)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background {
                                if mode == option {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(option.gradient)
                                }
                            }
                            .foregroundStyle(mode == option ? Color.white : Color.white.opacity(0.55))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mode-\(option.rawValue)")
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                }
            }
            .padding(2)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .sensoryFeedback(.selection, trigger: mode)
        }
        .padding(.top, 4)
    }
}

/// Kısa bilgi mesajı (üstte, fade in/out).
struct ToastView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(hex: 0x28282F).opacity(0.97), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: 0x33333D)))
            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            .accessibilityIdentifier("toast")
    }
}

/// "Net varlık (− borç)" satırı; hesaplanamıyorsa görünmez.
struct NetWorthRow: View {
    let net: Decimal?

    var body: some View {
        if let net {
            HStack {
                Text("Net varlık (− borç)").foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(MoneyFormatter.signed(net)).fontWeight(.bold).monospacedDigit()
            }
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("netWorth")
        }
    }
}

/// İlk açılışta ana ekran seçimi.
struct OnboardingView: View {
    let onChoose: (HomeMode) -> Void
    @State private var selection: HomeMode = .debt

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Hoş geldin 👋").font(.largeTitle.weight(.heavy))
                Text("Uygulama açılınca hangi ekran gelsin? Sonra üstteki anahtarla istediğin zaman değiştirebilirsin.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.bottom, 10)
                card(.debt, emoji: "💳", detail: "Krediler, elden borçlar, aylık taksitler")
                card(.savings, emoji: "🌱", detail: "Döviz, altın, TL birikimler ve alacaklar")
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 70)

            Button {
                onChoose(selection)
            } label: {
                Text("Devam")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(selection.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
    }

    private func card(_ mode: HomeMode, emoji: String, detail: String) -> some View {
        Button {
            selection = mode
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(emoji).font(.largeTitle)
                Text(mode.title).font(.title3.weight(.bold))
                Text(detail).font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.footer, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(selection == mode ? Theme.accent : Color(hex: 0x2A2A33), lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding-\(mode.rawValue)")
        .accessibilityAddTraits(selection == mode ? .isSelected : [])
    }
}
