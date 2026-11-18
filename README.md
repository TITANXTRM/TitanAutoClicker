# Titan Auto Clicker (iPadOS — Swift 6 / SwiftUI)

An independent, native iPadOS 17+ SwiftUI application inspired by the configuration model and workflow concepts of gesture-sequence auto clickers, built with strict Swift 6 concurrency, dark frosted-glass UI, and transparent iPadOS sandbox compliance.

> **Independent Implementation Notice:** Titan Auto Clicker is an original codebase with no copied source code, branding, assets, or affiliation with True Developers Studio or any third-party Android application.

## Platform Limitations (`PLATFORM_LIMITATION`)

iPadOS does not provide public equivalents to Android's `AccessibilityService.dispatchGesture` or `TYPE_ACCESSIBILITY_OVERLAY`. Titan does **not** use private APIs, jailbreaks, or fake workarounds:

| Capability | Status | Explanation |
| :--- | :--- | :--- |
| Cross-app simulated taps / swipes | `PLATFORM_LIMITATION` | iPadOS strictly sandboxes UI touch delivery between applications. |
| System-wide floating overlay bar | `PLATFORM_LIMITATION` | Public iPadOS SDKs do not allow drawing floating windows above arbitrary apps. |
| Background touch injection | `PLATFORM_LIMITATION` | iPadOS suspends background UI execution; Titan cleanly stops active runs on background transition. |

All gesture authoring, timing execution, interactive canvas dragging, live step visualization, and versioned JSON import/export work natively **inside Titan's foreground iPadOS workspace**.

## Architecture

- `App/` — `@main` SwiftUI entry point (`TitanAutoClickerApp`) and `NavigationSplitView` destinations.
- `Models/` — `Sendable` `Codable` domain types (`TargetPoint`, `TimeUnit`, `StopCondition`, `ExecutionSettings`, `AutomationConfiguration`, `PlatformLimitationItem`).
- `ExecutionEngine/` — `@MainActor` structured-concurrency deterministic state machine (`idle`, `running`, `paused`, `stopping`, `completed`, `failed`) with monotonic `runId` generation guards.
- `ConfigurationStorage/` — Atomic JSON persistence in Application Support (`ConfigurationStore`).
- `ImportExport/` — Two-phase strict `ConfigurationSchemaValidator` and `ConfigurationJSONDocument` (`FileDocument`).
- `Services/` — Canvas coordinate projection (`PreviewInteractionService`).
- `Utilities/` — Overflow-safe 64-bit `ValidationBounds` and `TitanTheme` design tokens.
- `ViewModels/` — `@Observable` `@MainActor` `TitanAppViewModel`.
- `Views/` — `RootSplitView`, `HomeDashboardView`, `TargetEditorView`, `SwipeEditorView`, `ConfigurationsView`, and reusable glass/canvas components.

## Building on macOS (Xcode 16+)

```bash
xcodebuild -project TitanAutoClicker.xcodeproj \
  -scheme TitanAutoClicker \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  build
```
