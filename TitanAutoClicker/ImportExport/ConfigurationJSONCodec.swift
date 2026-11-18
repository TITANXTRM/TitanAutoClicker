import Foundation
import SwiftUI
import UniformTypeIdentifiers

public enum ConfigurationJSONCodec: Sendable {
    public static func encode(_ configurations: [AutomationConfiguration]) throws -> Data {
        let envelope = ConfigurationExportEnvelope(
            schemaVersion: AutomationConfiguration.currentSchemaVersion,
            exportedAt: Date(),
            configurations: configurations
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(envelope)
    }

    public static func decodeAndValidate(_ data: Data) -> Result<ValidatedImportBundle, ConfigurationImportError> {
        ConfigurationSchemaValidator.validateImportData(data)
    }
}

/// SwiftUI FileDocument wrapper for native iPadOS `.fileExporter` JSON export.
public struct ConfigurationJSONDocument: FileDocument, Sendable {
    public static let readableContentTypes: [UTType] = [.json]

    public let data: Data

    public init(configurations: [AutomationConfiguration]) throws {
        self.data = try ConfigurationJSONCodec.encode(configurations)
    }

    public init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
