import SwiftUI

extension EnvironmentValues {
    /// Sabit üst alan sıkışıkken (küçük ekran / büyük yazı) kartlar kompakt çizilir.
    @Entry var isCompactHeader = false
}

/// Üst alan sabit, sadece içerik (liste) kayar.
/// Büyük erişilebilirlik yazısında veya üst alan ekranın yarısından uzunsa
/// hiçbir şey kesilmesin diye üst alan da kayan içeriğe katılır.
struct PinnedLayout<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var headerHeight: CGFloat = 0

    /// Bu yüksekliğin altında üst alan kompakt olur (iPhone 17e ≈ 760pt kullanılabilir alan).
    private var compactHeightThreshold: CGFloat { 780 }
    private var maxPinnedShare: CGFloat { 0.55 }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < compactHeightThreshold || typeSize > .xLarge
            let pinned = !typeSize.isAccessibilitySize
                && (headerHeight == 0 || headerHeight <= proxy.size.height * maxPinnedShare)

            Group {
                if pinned {
                    VStack(spacing: 0) {
                        headerContainer(pinned: true)
                        ScrollView { contentContainer }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            headerContainer(pinned: false)
                            contentContainer
                        }
                    }
                }
            }
            .environment(\.isCompactHeader, compact)
        }
    }

    private func headerContainer(pinned: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) { header }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
            .background(Theme.background)
            .overlay(alignment: .bottom) {
                if pinned { Theme.divider.frame(height: 1) }
            }
    }

    private var contentContainer: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
    }
}

extension View {
    /// Detay ekranları: bilgi satırı ve aksiyonlar listenin üstünde sabit kalır, sadece liste kayar.
    func pinnedTop<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) { header() }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.background)
                .overlay(alignment: .bottom) { Theme.divider.frame(height: 1) }
        }
    }
}
