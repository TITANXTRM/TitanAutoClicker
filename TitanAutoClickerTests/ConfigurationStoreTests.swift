import XCTest
@testable import TitanAutoClicker

final class ConfigurationStoreTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TitanStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testLoadAllCreatesStarterDefaultWhenFileMissing() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigurationStore(directoryURL: dir, filename: "configs.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Starter Sequence")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testSaveAllAndLoadAllRoundTrip() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigurationStore(directoryURL: dir, filename: "roundtrip.json")
        let custom = AutomationConfiguration(
            name: "Custom Workflow",
            mode: .multiTarget,
            targets: [
                TargetPoint(
                    label: "Step A",
                    kind: .tap,
                    startPoint: NormalizedPoint(x: 0.2, y: 0.3),
                    delayValue: 150,
                    delayUnit: .milliseconds,
                    durationMs: 40,
                    repeatCount: 2
                ),
                TargetPoint(
                    label: "Step B",
                    kind: .swipe,
                    startPoint: NormalizedPoint(x: 0.1, y: 0.8),
                    endPoint: NormalizedPoint(x: 0.9, y: 0.8),
                    delayValue: 2,
                    delayUnit: .seconds,
                    durationMs: 500,
                    repeatCount: 1
                )
            ],
            settings: ExecutionSettings(
                startDelayMs: 250,
                defaultIntervalValue: 300,
                defaultIntervalUnit: .milliseconds,
                stopCondition: .duration(seconds: 45),
                randomizePositionOffset: true
            )
        )

        try store.saveAll([custom])
        let reloaded = store.loadAll()

        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].id, custom.id)
        XCTAssertEqual(reloaded[0].name, "Custom Workflow")
        XCTAssertEqual(reloaded[0].targets.count, 2)
        XCTAssertEqual(reloaded[0].settings, custom.settings)
    }

    func testSaveAllCreatesMissingParentDirectory() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let nestedDir = dir.appendingPathComponent("Nested/Subfolder", isDirectory: true)
        let store = ConfigurationStore(directoryURL: nestedDir, filename: "nested.json")
        try FileManager.default.removeItem(at: nestedDir)

        XCTAssertFalse(FileManager.default.fileExists(atPath: nestedDir.path))
        try store.saveAll([AutomationConfiguration.sampleDefault()])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testCorruptFilePreservesBackupAndFallsBackToDefault() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ConfigurationStore(directoryURL: dir, filename: "corrupt.json")
        let corruptPayload = Data("{not valid json!!!".utf8)
        try corruptPayload.write(to: store.fileURL)

        let loaded = store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Starter Sequence")

        let backupURL = store.fileURL.appendingPathExtension("corrupt.bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        let backupContents = try Data(contentsOf: backupURL)
        XCTAssertEqual(backupContents, corruptPayload)
    }
}
