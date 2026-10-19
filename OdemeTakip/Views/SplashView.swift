import SwiftUI

/// Açılış: logo B'nin + ve − tuşları sırayla basılır, ad belirir, ~1 sn sonra biter.
struct SplashView: View {
    let onFinish: () -> Void

    @State private var plusPressed = false
    @State private var minusPressed = false
    @State private var showTitle = false

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
                Text("Ödeme Takip")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 8)
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
        withAnimation(.easeOut(duration: 0.3)) { showTitle = true }
        try? await Task.sleep(for: .milliseconds(500))
        onFinish()
    }
}
