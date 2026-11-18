import Foundation

public struct ConfigurationExportEnvelope: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var configurations: [AutomationConfiguration]

    public init(
        schemaVersion: Int = AutomationConfiguration.currentSchemaVersion,
        exportedAt: Date = Date(),
        configurations: [AutomationConfiguration]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.configurations = configurations
    }
}

public struct ValidatedImportBundle: Sendable {
    public let configurations: [AutomationConfiguration]
    public let warnings: [String]
}

public enum ConfigurationImportError: LocalizedError, Sendable {
    case fileTooLarge(bytes: Int)
    case invalidJSON(String)
    case unsupportedSchemaVersion(Int)
    case emptyPayload
    case corruptEntry(index: Int, reason: String)

    public var errorDescription: String? {
        switch self {
        case .fileTooLarge(let bytes):
            return "Import file is too large (\(bytes) bytes; limit is \(ValidationBounds.maxImportFileBytes) bytes)."
        case .invalidJSON(let detail):
            return "Invalid JSON format: \(detail)"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported configuration schema version: \(version)."
        case .emptyPayload:
            return "The selected JSON file contains no valid configurations."
        case .corruptEntry(let index, let reason):
            return "Configuration #\(index + 1) is invalid: \(reason)"
        }
    }
}

/// Two-phase strict JSON validator: decodes and sanitizes the entire payload in memory
/// before any caller commits changes to the live configuration store.
public enum ConfigurationSchemaValidator: Sendable {
    /// Loose raw DTOs to safely inspect missing, null, or out-of-range JSON fields without crashing.
    private struct RawEnvelope: Decodable {
        let schemaVersion: Int?
        let configurations: [RawConfiguration?]?
    }

    /// Safely decodes an ISO-8601 date string without failing the whole import payload on bad dates.
    private enum RawDateValue: Decodable {
        case valid(Date)
        case invalid

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                if let parsed = Self.parseISO8601(str) {
                    self = .valid(parsed)
                    return
                }
            } else if let seconds = try? container.decode(Double.self), seconds.isFinite {
                self = .valid(Date(timeIntervalSince1970: seconds))
                return
            }
            self = .invalid
        }

        private static func parseISO8601(_ string: String) -> Date? {
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = standard.date(from: string) {
                return date
            }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: string)
        }
    }

    /// Isolates malformed `stopCondition` entries so errors report the exact configuration index.
    private enum RawStopCondition: Decodable {
        case valid(StopCondition)
        case invalid

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let parsed = try? container.decode(StopCondition.self) {
                self = .valid(parsed)
            } else {
                self = .invalid
            }
        }
    }

    private struct RawConfiguration: Decodable {
        let schemaVersion: Int?
        let id: String?
        let name: String?
        let mode: String?
        let targets: [RawTarget?]?
        let settings: RawSettings?
        let createdAt: RawDateValue?
        let updatedAt: RawDateValue?
    }

    private struct RawTarget: Decodable {
        let id: String?
        let label: String?
        let kind: String?
        let startPoint: RawPoint?
        let endPoint: RawPoint?
        let delayValue: Int?
        let delayUnit: String?
        let durationMs: Int?
        let repeatCount: Int?
    }

    private struct RawPoint: Decodable {
        let x: Double?
        let y: Double?
    }

    private struct RawSettings: Decodable {
        let startDelayMs: Int?
        let defaultIntervalValue: Int?
        let defaultIntervalUnit: String?
        let stopCondition: RawStopCondition?
        let randomizePositionOffset: Bool?
    }

    public static func validateImportData(_ data: Data) -> Result<ValidatedImportBundle, ConfigurationImportError> {
        guard data.count <= ValidationBounds.maxImportFileBytes else {
            return .failure(.fileTooLarge(bytes: data.count))
        }

        let decoder = JSONDecoder()

        let rawConfigs: [RawConfiguration?]
        let declaredVersion: Int

        if let envelope = try? decoder.decode(RawEnvelope.self, from: data),
           let list = envelope.configurations {
            declaredVersion = envelope.schemaVersion ?? AutomationConfiguration.currentSchemaVersion
            rawConfigs = list
        } else if let bareArray = try? decoder.decode([RawConfiguration?].self, from: data) {
            declaredVersion = AutomationConfiguration.currentSchemaVersion
            rawConfigs = bareArray
        } else {
            return .failure(.invalidJSON("Expected a Titan configuration envelope or JSON array of configurations."))
        }

        guard declaredVersion >= 1 && declaredVersion <= AutomationConfiguration.currentSchemaVersion else {
            return .failure(.unsupportedSchemaVersion(declaredVersion))
        }

        guard !rawConfigs.isEmpty else {
            return .failure(.emptyPayload)
        }

        var validated: [AutomationConfiguration] = []
        var warnings: [String] = []
        var seenConfigIds: Set<UUID> = []

        for (index, optionalRaw) in rawConfigs.enumerated() {
            guard let raw = optionalRaw else {
                return .failure(.corruptEntry(index: index, reason: "Null configuration entry encountered."))
            }

            if let entryVersion = raw.schemaVersion,
               entryVersion < 1 || entryVersion > AutomationConfiguration.currentSchemaVersion {
                return .failure(.unsupportedSchemaVersion(entryVersion))
            }

            let mode: AutomationMode
            if let rawMode = raw.mode {
                guard let parsedMode = AutomationMode(rawValue: rawMode) else {
                    return .failure(.corruptEntry(index: index, reason: "Unknown automation mode '\(rawMode)'."))
                }
                mode = parsedMode
            } else {
                mode = .multiTarget
                warnings.append("Configuration #\(index + 1) omitted mode; defaulted to Multi Target.")
            }

            var sanitizedTargets: [TargetPoint] = []
            var seenTargetIds: Set<UUID> = []
            if let rawTargets = raw.targets {
                if rawTargets.count > ValidationBounds.maxTargetsPerConfiguration {
                    warnings.append("Configuration #\(index + 1) exceeded \(ValidationBounds.maxTargetsPerConfiguration) targets and was truncated.")
                }
                for (tIdx, optionalTarget) in rawTargets.prefix(ValidationBounds.maxTargetsPerConfiguration).enumerated() {
                    guard let rawTarget = optionalTarget else {
                        return .failure(.corruptEntry(index: index, reason: "Target #\(tIdx + 1) is null."))
                    }
                    let kind: TargetKind
                    if let rawKind = rawTarget.kind {
                        guard let parsedKind = TargetKind(rawValue: rawKind) else {
                            return .failure(.corruptEntry(index: index, reason: "Target #\(tIdx + 1) has unknown kind '\(rawKind)'."))
                        }
                        kind = parsedKind
                    } else {
                        kind = .tap
                    }

                    let unit: TimeUnit
                    if let rawUnit = rawTarget.delayUnit {
                        if let parsedUnit = TimeUnit(rawValue: rawUnit) {
                            unit = parsedUnit
                        } else {
                            unit = .milliseconds
                            warnings.append("Configuration #\(index + 1) Target #\(tIdx + 1) had unknown delayUnit '\(rawUnit)'; defaulted to ms.")
                        }
                    } else {
                        unit = .milliseconds
                    }

                    let start = NormalizedPoint(
                        x: rawTarget.startPoint?.x ?? 0.5,
                        y: rawTarget.startPoint?.y ?? 0.5
                    )
                    let defaultSwipeEnd = TargetPoint.defaultSwipeEndPoint(from: start)
                    let end: NormalizedPoint? = (kind == .swipe)
                        ? NormalizedPoint(
                            x: rawTarget.endPoint?.x ?? defaultSwipeEnd.x,
                            y: rawTarget.endPoint?.y ?? defaultSwipeEnd.y
                        )
                        : nil

                    var targetId = rawTarget.id.flatMap(UUID.init(uuidString:)) ?? UUID()
                    if !seenTargetIds.insert(targetId).inserted {
                        targetId = UUID()
                        warnings.append("Configuration #\(index + 1) Target #\(tIdx + 1) had a duplicate id; reassigned a unique id.")
                    }

                    let target = TargetPoint(
                        id: targetId,
                        label: rawTarget.label ?? "Target \(tIdx + 1)",
                        kind: kind,
                        startPoint: start,
                        endPoint: end,
                        delayValue: rawTarget.delayValue ?? 300,
                        delayUnit: unit,
                        durationMs: rawTarget.durationMs,
                        repeatCount: rawTarget.repeatCount ?? 1
                    ).validated(fallbackLabel: "Target \(tIdx + 1)")

                    sanitizedTargets.append(target)
                }
            }

            let rawSettings = raw.settings
            let intervalUnit: TimeUnit
            if let rawIntervalUnit = rawSettings?.defaultIntervalUnit {
                if let parsedUnit = TimeUnit(rawValue: rawIntervalUnit) {
                    intervalUnit = parsedUnit
                } else {
                    intervalUnit = .milliseconds
                    warnings.append("Configuration #\(index + 1) had unknown defaultIntervalUnit '\(rawIntervalUnit)'; defaulted to ms.")
                }
            } else {
                intervalUnit = .milliseconds
            }

            let stopCondition: StopCondition
            switch rawSettings?.stopCondition {
            case .valid(let parsed):
                stopCondition = parsed.validated()
            case .invalid:
                return .failure(.corruptEntry(index: index, reason: "Invalid stopCondition format."))
            case nil:
                stopCondition = .cycles(count: 10)
            }

            let settings = ExecutionSettings(
                startDelayMs: rawSettings?.startDelayMs ?? 500,
                defaultIntervalValue: rawSettings?.defaultIntervalValue ?? 300,
                defaultIntervalUnit: intervalUnit,
                stopCondition: stopCondition,
                randomizePositionOffset: rawSettings?.randomizePositionOffset ?? false
            )

            let now = Date()
            let createdAt: Date
            switch raw.createdAt {
            case .valid(let d):
                createdAt = d
            case .invalid:
                createdAt = now
                warnings.append("Configuration #\(index + 1) had an invalid createdAt timestamp; defaulted to current time.")
            case nil:
                createdAt = now
            }

            let updatedAt: Date
            switch raw.updatedAt {
            case .valid(let d):
                updatedAt = d
            case .invalid:
                updatedAt = now
                warnings.append("Configuration #\(index + 1) had an invalid updatedAt timestamp; defaulted to current time.")
            case nil:
                updatedAt = now
            }

            var configId = raw.id.flatMap(UUID.init(uuidString:)) ?? UUID()
            if !seenConfigIds.insert(configId).inserted {
                configId = UUID()
                warnings.append("Configuration #\(index + 1) had a duplicate id; reassigned a unique id.")
            }

            let config = AutomationConfiguration(
                schemaVersion: AutomationConfiguration.currentSchemaVersion,
                id: configId,
                name: raw.name ?? "Imported Profile \(index + 1)",
                mode: mode,
                targets: sanitizedTargets,
                settings: settings,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
            validated.append(config)
        }

        return .success(ValidatedImportBundle(configurations: validated, warnings: warnings))
    }
}
