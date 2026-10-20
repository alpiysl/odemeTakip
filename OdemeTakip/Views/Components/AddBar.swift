import SwiftUI

/// Alttaki sabit, tam genişlik "＋ Yeni …" buton görünümü.
struct AddBarLabel: View {
    let title: String
    let gradient: LinearGradient

    var body: some View {
        Label(title, systemImage: "plus")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .lineLimit(1)
            .background(gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

extension View {
    /// İçeriğin altına sabit bir buton şeridi ekler. İçerik alanı şeridin üstünde biter;
    /// liste satırları şeridin arkasına hiç giremez.
    func addBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        VStack(spacing: 0) {
            self
            Theme.divider.frame(height: 1)
            bar()
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
