import SwiftUI

/// Açılış: logo B'nin + ve − tuşları sırayla basılır; ~2 sn sonra biter.
struct SplashView: View {
    let onFinish: () -> Void

    @State private var plusPressed = false
    @State private var minusPressed = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 10) {
                key(symbol: "plus", symbolColor: .white, pressed: plusPressed) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: 0x6E6CF0), Color(hex: 0xC76AF5)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                key(symbol: "minus", symbolColor: Theme.cash, pressed: minusPressed) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: 0x26262E))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("splash")
        .task { await play() }
    }

    private func key<Background: View>(symbol: String, symbolColor: Color, pressed: Bool,
                                       @ViewBuilder background: () -> Background) -> some View {
        background()
            .frame(width: 180, height: 84)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(symbolColor)
            }
            .scaleEffect(pressed ? 0.9 : 1)
    }

    private func play() async {
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.easeInOut(duration: 0.12)) { plusPressed = true }
        try? await Task.sleep(for: .milliseconds(130))
        withAnimation(.spring(duration: 0.25)) { plusPressed = false }
        withAnimation(.easeInOut(duration: 0.12)) { minusPressed = true }
        try? await Task.sleep(for: .milliseconds(130))
        withAnimation(.spring(duration: 0.25)) { minusPressed = false }
        try? await Task.sleep(for: .milliseconds(1_400))
        onFinish()
    }
}
