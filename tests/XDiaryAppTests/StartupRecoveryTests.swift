import Foundation
import Testing
import XDiaryCore
@testable import xdiary

@MainActor
@Suite("StartupRecoveryTests")
struct StartupRecoveryTests {
    @Test("损坏主数据后可用完整备份恢复并重新进入应用")
    func restoresValidBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let dataURL = directory.appendingPathComponent("xdiary-data.json")
        let backupURL = directory.appendingPathComponent("backup.json")
        try Data("损坏内容".utf8).write(to: dataURL)
        var backup = DiaryDefaults.initialData()
        let templateID = try #require(backup.defaultTemplateID)
        try backup.createEntry(on: "2026-09-11", templateID: templateID)
        try DiaryBackup.encode(backup).write(to: backupURL)

        let bootstrap = AppBootstrap(dataURL: dataURL)
        #expect(bootstrap.store == nil)

        bootstrap.restore(from: backupURL)

        #expect(bootstrap.error == nil)
        #expect(bootstrap.store?.data.entries.map(\.date) == ["2026-09-11"])
        #expect(try DiaryFileStore.load(from: dataURL).entries.map(\.date) == ["2026-09-11"])
    }

    @Test("无效备份不会覆盖原来的主数据文件")
    func invalidBackupDoesNotOverwriteLocalFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let dataURL = directory.appendingPathComponent("xdiary-data.json")
        let backupURL = directory.appendingPathComponent("backup.json")
        let original = Data("原文件仍需保留".utf8)
        try original.write(to: dataURL)
        try Data("不是备份".utf8).write(to: backupURL)

        let bootstrap = AppBootstrap(dataURL: dataURL)
        bootstrap.restore(from: backupURL)

        #expect(bootstrap.store == nil)
        #expect(bootstrap.error?.contains("恢复失败") == true)
        #expect(try Data(contentsOf: dataURL) == original)
    }
}
