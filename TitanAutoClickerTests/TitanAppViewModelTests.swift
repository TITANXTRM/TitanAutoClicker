import XCTest
@testable import TitanAutoClicker

@MainActor
final class TitanAppViewModelTests: XCTestCase {
    private func makeIsolatedViewModel() throws -> (TitanAppViewModel, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TitanVMTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = ConfigurationStore(directoryURL: dir, filename: "vm_configs.json")
        let vm = TitanAppViewModel(store: store, engine: ExecutionEngine())
        return (vm, dir)
    }

    func testTargetCRUDAndReordering() throws {
        let (vm, dir) = try makeIsolatedViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        let initialCount = vm.activeConfiguration.targets.count
        vm.addTapTarget(at: NormalizedPoint(x: 0.15, y: 0.85))
        XCTAssertEqual(vm.activeConfiguration.targets.count, initialCount + 1)

        let addedTapId = try XCTUnwrap(vm.selectedTargetId)
        vm.addSwipeTarget(from: NormalizedPoint(x: 0.1, y: 0.2), to: NormalizedPoint(x: 0.9, y: 0.2))
        XCTAssertEqual(vm.activeConfiguration.targets.count, initialCount + 2)

        // Move last item to index 0
        let lastIdx = vm.activeConfiguration.targets.count - 1
        let movedId = vm.activeConfiguration.targets[lastIdx].id
        vm.moveTargets(from: IndexSet(integer: lastIdx), to: 0)
        XCTAssertEqual(vm.activeConfiguration.targets.first?.id, movedId)

        // Update label
        var target = try XCTUnwrap(vm.activeConfiguration.targets.first(where: { $0.id == addedTapId }))
        target.label = "Updated Tap"
        vm.updateTarget(target)
        XCTAssertEqual(vm.activeConfiguration.targets.first(where: { $0.id == addedTapId })?.label, "Updated Tap")

        // Remove target
        vm.removeTarget(id: addedTapId)
        XCTAssertFalse(vm.activeConfiguration.targets.contains(where: { $0.id == addedTapId }))
    }

    func testAllMutationsLockedWhileExecutionIsActive() async throws {
        let (vm, dir) = try makeIsolatedViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        vm.updateSettings {
            $0.startDelayMs = 0
            $0.stopCondition = .indefinite
        }
        let originalConfigId = vm.activeConfiguration.id
        let originalName = vm.activeConfiguration.name
        let originalCount = vm.configurations.count
        let originalTargetCount = vm.activeConfiguration.targets.count

        // Prepare a valid import file to verify import is also blocked while active
        let importURL = dir.appendingPathComponent("valid_import.json")
        let exportData = try ConfigurationJSONCodec.encode([AutomationConfiguration.sampleDefault()])
        try exportData.write(to: importURL)

        vm.startExecution()
        XCTAssertTrue(vm.engine.state.isActive)

        vm.setMode(.singleTarget)
        vm.addTapTarget()
        vm.addSwipeTarget()
        vm.createNewConfiguration(name: "Blocked")
        vm.renameConfiguration(id: originalConfigId, newName: "Blocked Rename")
        vm.duplicateConfiguration(id: originalConfigId)
        vm.deleteConfiguration(id: originalConfigId)
        vm.importConfigurations(from: importURL)

        XCTAssertEqual(vm.configurations.count, originalCount)
        XCTAssertEqual(vm.activeConfiguration.id, originalConfigId)
        XCTAssertEqual(vm.activeConfiguration.name, originalName)
        XCTAssertEqual(vm.activeConfiguration.targets.count, originalTargetCount)

        vm.stopExecution()
        try? await Task.sleep(for: .milliseconds(100))
    }

    func testSelectUnknownConfigurationIdIgnored() throws {
        let (vm, dir) = try makeIsolatedViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        let currentId = vm.selectedConfigurationId
        vm.selectConfiguration(id: UUID())
        XCTAssertEqual(vm.selectedConfigurationId, currentId)
    }

    func testImportAssignsFreshConfigAndTargetUUIDs() throws {
        let (vm, dir) = try makeIsolatedViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        let existingConfig = vm.activeConfiguration
        let existingTargetIds = Set(existingConfig.targets.map(\.id))

        let importURL = dir.appendingPathComponent("reimport.json")
        let payload = try ConfigurationJSONCodec.encode([existingConfig])
        try payload.write(to: importURL)

        vm.importConfigurations(from: importURL)
        XCTAssertNil(vm.lastErrorMessage)
        XCTAssertEqual(vm.configurations.count, 2)

        let imported = vm.configurations[0]
        XCTAssertNotEqual(imported.id, existingConfig.id)
        let importedTargetIds = Set(imported.targets.map(\.id))
        XCTAssertTrue(importedTargetIds.isDisjoint(with: existingTargetIds))
    }

    func testMalformedImportPreservesExistingConfigurations() throws {
        let (vm, dir) = try makeIsolatedViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        let before = vm.configurations
        let badURL = dir.appendingPathComponent("bad.json")
        try Data("{ invalid json".utf8).write(to: badURL)

        vm.importConfigurations(from: badURL)
        XCTAssertEqual(vm.configurations, before)
        XCTAssertNotNil(vm.lastErrorMessage)
    }

    func testDeleteLastConfigurationRestoresSampleDefault() throws {
        let (vm, dir) = try makeIsolatedViewModel()
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertEqual(vm.configurations.count, 1)
        let onlyId = vm.configurations[0].id
        vm.deleteConfiguration(id: onlyId)

        XCTAssertEqual(vm.configurations.count, 1)
        XCTAssertNotEqual(vm.configurations[0].id, onlyId)
        XCTAssertEqual(vm.selectedConfigurationId, vm.configurations[0].id)
    }
}
