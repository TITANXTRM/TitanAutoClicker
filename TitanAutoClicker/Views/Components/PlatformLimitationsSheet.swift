import SwiftUI

/// Explicit, transparent disclosure sheet documenting iPadOS PLATFORM_LIMITATION items.
public struct PlatformLimitationsSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Titan Auto Clicker is built strictly with public Apple iPadOS frameworks. Features requiring Android AccessibilityService or global window overlays are explicitly marked PLATFORM_LIMITATION below.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(PlatformLimitationItem.ipadosLimitations) { item in
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.code)
                                        .font(.caption2.weight(.bold).monospaced())
                                        .foregroundStyle(TitanTheme.statusPaused)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(TitanTheme.statusPaused.opacity(0.16), in: Capsule())
                                    Spacer()
                                }
                                Text(item.featureName)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(item.reason)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Divider().overlay(TitanTheme.surfaceStroke)
                                Label(item.supportedAlternative, systemImage: "checkmark.shield.fill")
                                    .font(.footnote)
                                    .foregroundStyle(TitanTheme.accentPrimary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(TitanTheme.canvasBackground.ignoresSafeArea())
            .navigationTitle("iPadOS Platform Boundaries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
