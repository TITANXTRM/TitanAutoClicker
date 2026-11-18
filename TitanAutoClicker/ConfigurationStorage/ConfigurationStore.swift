import Foundation

public enum ConfigurationStoreError: LocalizedError, Sendable {
    case directoryUnavailable
    case encodingFailed(String)
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "Application Support directory is unavailable."
        case .encodingFailed(let reason):
            return "Failed to encode configurations: \(reason)"
        case .persistenceFailed(let reason):
            return "Failed to save configurations to disk: \(reason)"
        }
    }
}

/// Atomic file-backed persistence store for Titan configurations using Application Support.
public final class ConfigurationStore: Sendable {
    public let fileURL: URL

    public init(fileManager: FileManager = .default, filename: String = "titan_configurations_v1.json") {
        let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = baseDir.appendingPathComponent("TitanAutoClicker", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent(filename, isDirectory: false)
    }

    /// Designated initializer for explicit directory injection (e.g., isolated temporary directories in unit tests).
    public init(directoryURL: URL, filename: String = "titan_configurations_v1.json") {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        self.fileURL = directoryURL.appendingPathComponent(filename, isDirectory: false)
    }

    public func loadAll() -> [AutomationConfiguration] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let starter = [AutomationConfiguration.sampleDefault()]
            try? saveAll(starter)
            return starter
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let result = ConfigurationSchemaValidator.validateImportData(data)
            switch result {
            case .success(let validated):
                return validated.configurations.isEmpty ? [AutomationConfiguration.sampleDefault()] : validated.configurations
            case .failure:
                preserveCorruptFileBackup()
                return [AutomationConfiguration.sampleDefault()]
            }
        } catch {
            preserveCorruptFileBackup()
            return [AutomationConfiguration.sampleDefault()]
        }
    }

    public func saveAll(_ configurations: [AutomationConfiguration]) throws {
        let envelope = ConfigurationExportEnvelope(
            schemaVersion: AutomationConfiguration.currentSchemaVersion,
            exportedAt: Date(),
            configurations: configurations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data: Data
        do {
            data = try encoder.encode(envelope)
        } catch {
            throw ConfigurationStoreError.encodingFailed(error.localizedDescription)
        }
        do {
            let parentDir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw ConfigurationStoreError.persistenceFailed(error.localizedDescription)
        }
    }

    private func preserveCorruptFileBackup() {
        let backupURL = fileURL.appendingPathExtension("corrupt.bak")
        let fm = FileManager.default
        if fm.fileExists(atPath: backupURL.path) {
            try? fm.removeItem(at: backupURL)
        }
        try? fm.copyItem(at: fileURL, to: backupURL)
    }
}
