import SwiftUI

/// Dark frosted-glass panel container tailored for iPadOS dashboards.
public struct GlassPanel<Content: View>: View {
    private let title: String?
    private let systemImage: String?
    private let content: Content

    public init(
        title: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(TitanTheme.accentPrimary)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
            content
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: TitanTheme.panelCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TitanTheme.panelCornerRadius, style: .continuous)
                .strokeBorder(TitanTheme.surfaceStroke, lineWidth: 1)
        )
    }
}
