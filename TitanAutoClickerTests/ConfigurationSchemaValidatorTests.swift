import XCTest
@testable import TitanAutoClicker

final class ConfigurationSchemaValidatorTests: XCTestCase {
    func testValidEnvelopeEncodeDecodeRoundTrip() throws {
        let original = [AutomationConfiguration.sampleDefault()]
        let encoded = try ConfigurationJSONCodec.encode(original)
        let result = ConfigurationJSONCodec.decodeAndValidate(encoded)

        switch result {
        case .failure(let error):
            XCTFail("Expected valid round-trip, got error: \(error.localizedDescription)")
        case .success(let bundle):
            XCTAssertTrue(bundle.warnings.isEmpty)
            XCTAssertEqual(bundle.configurations.count, 1)
            XCTAssertEqual(bundle.configurations[0].name, original[0].name)
            XCTAssertEqual(bundle.configurations[0].mode, original[0].mode)
            XCTAssertEqual(bundle.configurations[0].targets.count, original[0].targets.count)
            XCTAssertEqual(bundle.configurations[0].settings, original[0].settings)
        }
    }

    func testBareArrayImportSucceeds() throws {
        let json = """
        [
          {
            "schemaVersion": 1,
            "name": "Bare Array Profile",
            "mode": "singleTarget",
            "targets": [
              { "label": "Center", "kind": "tap", "startPoint": { "x": 0.5, "y": 0.5 }, "delayValue": 250, "delayUnit": "milliseconds" }
            ]
          }
        ]
        """
        let result = ConfigurationSchemaValidator.validateImportData(Data(json.utf8))
        switch result {
        case .failure(let error):
            XCTFail("Expected bare array to validate, got: \(error.localizedDescription)")
        case .success(let bundle):
            XCTAssertEqual(bundle.configurations.count, 1)
            XCTAssertEqual(bundle.configurations[0].name, "Bare Array Profile")
            XCTAssertEqual(bundle.configurations[0].mode, .singleTarget)
        }
    }

    func testBareArrayUnsupportedSchemaVersionRejected() {
        let json = """
        [
          {
            "schemaVersion": 99,
            "name": "Future Bare Profile",
            "mode": "multiTarget",
            "targets": []
          }
        ]
        """
        let result = ConfigurationSchemaValidator.validateImportData(Data(json.utf8))
        guard case .failure(.unsupportedSchemaVersion(99)) = result else {
            return XCTFail("Expected .unsupportedSchemaVersion(99), got \(result)")
        }
    }

    func testEnvelopeUnsupportedSchemaVersionRejected() {
        let futureJSON = """
        { "schemaVersion": 2, "configurations": [{ "name": "Future", "mode": "multiTarget", "targets": [] }] }
        """
        guard case .failure(.unsupportedSchemaVersion(2)) = ConfigurationSchemaValidator.validateImportData(Data(futureJSON.utf8)) else {
            return XCTFail("Expected .unsupportedSchemaVersion(2)")
        }

        let zeroJSON = """
        { "schemaVersion": 0, "configurations": [{ "name": "Legacy", "mode": "multiTarget", "targets": [] }] }
        """
        guard case .failure(.unsupportedSchemaVersion(0)) = ConfigurationSchemaValidator.validateImportData(Data(zeroJSON.utf8)) else {
            return XCTFail("Expected .unsupportedSchemaVersion(0)")
        }
    }

    func testEmptyAndMalformedPayloadsRejected() {
        for raw in ["null", "{}", "{bad json", "\"hello\""] {
            guard case .failure(.invalidJSON) = ConfigurationSchemaValidator.validateImportData(Data(raw.utf8)) else {
                return XCTFail("Expected .invalidJSON for payload: \(raw)")
            }
        }

        for empty in ["[]", "{\"schemaVersion\": 1, \"configurations\": []}"] {
            guard case .failure(.emptyPayload) = ConfigurationSchemaValidator.validateImportData(Data(empty.utf8)) else {
                return XCTFail("Expected .emptyPayload for payload: \(empty)")
            }
        }
    }

    func testNullConfigEntryAndNullTargetRejected() {
        let nullConfig = """
        { "schemaVersion": 1, "configurations": [null] }
        """
        guard case .failure(.corruptEntry(let cfgIndex, _)) = ConfigurationSchemaValidator.validateImportData(Data(nullConfig.utf8)) else {
            return XCTFail("Expected .corruptEntry for null configuration")
        }
        XCTAssertEqual(cfgIndex, 0)

        let nullTarget = """
        { "schemaVersion": 1, "configurations": [{ "name": "Bad", "mode": "multiTarget", "targets": [null] }] }
        """
        guard case .failure(.corruptEntry(let tCfgIndex, _)) = ConfigurationSchemaValidator.validateImportData(Data(nullTarget.utf8)) else {
            return XCTFail("Expected .corruptEntry for null target")
        }
        XCTAssertEqual(tCfgIndex, 0)
    }

    func testUnknownModeAndUnknownTargetKindRejected() {
        let badMode = """
        { "schemaVersion": 1, "configurations": [{ "name": "X", "mode": "teleport", "targets": [] }] }
        """
        guard case .failure(.corruptEntry(0, _)) = ConfigurationSchemaValidator.validateImportData(Data(badMode.utf8)) else {
            return XCTFail("Expected .corruptEntry for unknown mode")
        }

        let badKind = """
        { "schemaVersion": 1, "configurations": [{ "name": "X", "mode": "multiTarget", "targets": [{ "kind": "pinch" }] }] }
        """
        guard case .failure(.corruptEntry(0, _)) = ConfigurationSchemaValidator.validateImportData(Data(badKind.utf8)) else {
            return XCTFail("Expected .corruptEntry for unknown target kind")
        }
    }

    func testDuplicateIdsDeduplicatedWithWarnings() {
        let dupConfigId = UUID().uuidString
        let dupTargetId = UUID().uuidString
        let json = """
        {
          "schemaVersion": 1,
          "configurations": [
            {
              "id": "\(dupConfigId)",
              "name": "First",
              "mode": "multiTarget",
              "targets": [
                { "id": "\(dupTargetId)", "label": "T1", "kind": "tap", "startPoint": { "x": 0.2, "y": 0.2 } },
                { "id": "\(dupTargetId)", "label": "T2", "kind": "tap", "startPoint": { "x": 0.8, "y": 0.8 } }
              ]
            },
            {
              "id": "\(dupConfigId)",
              "name": "Second",
              "mode": "multiTarget",
              "targets": []
            }
          ]
        }
        """
        let result = ConfigurationSchemaValidator.validateImportData(Data(json.utf8))
        switch result {
        case .failure(let error):
            XCTFail("Expected duplicate IDs to be deduplicated, got: \(error.localizedDescription)")
        case .success(let bundle):
            XCTAssertEqual(bundle.configurations.count, 2)
            XCTAssertNotEqual(bundle.configurations[0].id, bundle.configurations[1].id)
            XCTAssertEqual(bundle.configurations[0].targets.count, 2)
            XCTAssertNotEqual(bundle.configurations[0].targets[0].id, bundle.configurations[0].targets[1].id)
            XCTAssertGreaterThanOrEqual(bundle.warnings.count, 2)
        }
    }

    func testUnknownUnitsAndBadDatesEmitWarnings() {
        let json = """
        {
          "schemaVersion": 1,
          "configurations": [
            {
              "name": "Unit Test",
              "mode": "multiTarget",
              "createdAt": "not-a-date",
              "updatedAt": "also-bad",
              "targets": [
                { "label": "T1", "kind": "tap", "delayValue": 5, "delayUnit": "hours" }
              ],
              "settings": {
                "defaultIntervalValue": 10,
                "defaultIntervalUnit": "days"
              }
            }
          ]
        }
        """
        let result = ConfigurationSchemaValidator.validateImportData(Data(json.utf8))
        switch result {
        case .failure(let error):
            XCTFail("Expected graceful fallback with warnings, got: \(error.localizedDescription)")
        case .success(let bundle):
            XCTAssertEqual(bundle.configurations[0].targets[0].delayUnit, .milliseconds)
            XCTAssertEqual(bundle.configurations[0].settings.defaultIntervalUnit, .milliseconds)
            XCTAssertGreaterThanOrEqual(bundle.warnings.count, 4)
        }
    }

    func testMalformedStopConditionReportsCorruptEntry() {
        let json = """
        {
          "schemaVersion": 1,
          "configurations": [
            {
              "name": "Bad Stop Condition",
              "mode": "multiTarget",
              "targets": [],
              "settings": {
                "stopCondition": { "unknownMode": { "foo": 1 } }
              }
            }
          ]
        }
        """
        guard case .failure(.corruptEntry(0, _)) = ConfigurationSchemaValidator.validateImportData(Data(json.utf8)) else {
            return XCTFail("Expected .corruptEntry(0, ...) for malformed stopCondition")
        }
    }

    func testOversizedPayloadRejected() {
        let oversized = Data(repeating: 0x20, count: ValidationBounds.maxImportFileBytes + 1)
        guard case .failure(.fileTooLarge) = ConfigurationSchemaValidator.validateImportData(oversized) else {
            return XCTFail("Expected .fileTooLarge for payload exceeding 5 MB")
        }
    }

    func testNumericClampingAndEdgeSwipeEndPoint() {
        let json = """
        {
          "schemaVersion": 1,
          "configurations": [
            {
              "name": "Clamped",
              "mode": "multiTarget",
              "targets": [
                {
                  "label": "Edge Swipe",
                  "kind": "swipe",
                  "startPoint": { "x": 5.0, "y": -2.0 },
                  "delayValue": -10,
                  "delayUnit": "milliseconds",
                  "durationMs": 5,
                  "repeatCount": 999999
                }
              ],
              "settings": {
                "startDelayMs": -100,
                "defaultIntervalValue": 0,
                "defaultIntervalUnit": "seconds"
              }
            }
          ]
        }
        """
        let result = ConfigurationSchemaValidator.validateImportData(Data(json.utf8))
        switch result {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error.localizedDescription)")
        case .success(let bundle):
            let cfg = bundle.configurations[0]
            XCTAssertEqual(cfg.settings.startDelayMs, ValidationBounds.minStartDelayMs)
            XCTAssertEqual(cfg.settings.defaultIntervalValue, ValidationBounds.minDelayValue)
            let target = cfg.targets[0]
            XCTAssertEqual(target.startPoint.x, 1.0, accuracy: 0.0001)
            XCTAssertEqual(target.startPoint.y, 0.0, accuracy: 0.0001)
            XCTAssertEqual(target.endPoint?.x ?? -1, 0.8, accuracy: 0.0001)
            XCTAssertEqual(target.durationMs, ValidationBounds.minSwipeDurationMs)
            XCTAssertEqual(target.repeatCount, ValidationBounds.maxRepeatCount)
        }
    }
}
