import Foundation

/// Explicitly documents Android AccessibilityService capabilities that cannot be
/// implemented using public iPadOS APIs, marked as PLATFORM_LIMITATION.
public struct PlatformLimitationItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let featureName: String
    public let reason: String
    public let supportedAlternative: String

    public static let ipadosLimitations: [PlatformLimitationItem] = [
        PlatformLimitationItem(
            id: "cross-app-touch-injection",
            code: "PLATFORM_LIMITATION",
            featureName: "Cross-Application Simulated Taps & Swipes",
            reason: "iPadOS enforces strict process and UI sandboxing and provides no public equivalent to Android AccessibilityService.dispatchGesture for injecting synthetic touch events into other applications.",
            supportedAlternative: "Titan executes deterministic gesture sequences natively inside its own Interactive Preview Canvas for timing verification, workflow design, and JSON profile authoring."
        ),
        PlatformLimitationItem(
            id: "global-floating-overlay",
            code: "PLATFORM_LIMITATION",
            featureName: "System-Wide Floating Controller Bar Overlay",
            reason: "Public iPadOS SDKs do not allow drawing persistent floating windows above arbitrary third-party apps (no equivalent to Android TYPE_ACCESSIBILITY_OVERLAY).",
            supportedAlternative: "Use native iPadOS Split View / Stage Manager side-by-side layout with Titan's responsive dark control dashboard."
        ),
        PlatformLimitationItem(
            id: "background-touch-automation",
            code: "PLATFORM_LIMITATION",
            featureName: "Background Touch Injection",
            reason: "iPadOS suspends background UI execution and prohibits hidden background touch synthesis via public APIs.",
            supportedAlternative: "Foreground in-app execution with explicit Pause, Resume, Stop, and clean background-transition cancellation."
        )
    ]
}
