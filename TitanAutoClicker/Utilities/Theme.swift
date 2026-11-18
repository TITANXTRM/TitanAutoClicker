import SwiftUI

/// Original dark-first visual identity tokens for Titan Auto Clicker.
public enum TitanTheme {
    public static let canvasBackground = Color(red: 0.06, green: 0.07, blue: 0.10)
    public static let surfaceElevated = Color(red: 0.10, green: 0.12, blue: 0.17)
    public static let surfaceStroke = Color.white.opacity(0.10)

    public static let accentPrimary = Color(red: 0.24, green: 0.72, blue: 0.98)   // Titan Cyan
    public static let accentSecondary = Color(red: 0.45, green: 0.49, blue: 0.98) // Indigo
    public static let statusRunning = Color(red: 0.19, green: 0.84, blue: 0.56)   // Emerald
    public static let statusPaused = Color(red: 0.98, green: 0.75, blue: 0.24)    // Amber
    public static let statusDanger = Color(red: 0.96, green: 0.36, blue: 0.42)    // Coral Red

    public static let panelCornerRadius: CGFloat = 18
    public static let controlCornerRadius: CGFloat = 12
}
