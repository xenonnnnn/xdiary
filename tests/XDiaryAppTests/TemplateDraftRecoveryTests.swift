import Foundation
import Testing
import XDiaryCore
@testable import xdiary

@Suite("TemplateDraftRecoveryTests")
struct TemplateDraftRecoveryTests {
    @Test("未保存的模板修改会写入恢复文件，重新打开后可继续编辑")
    func dirtyDraftRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dataURL = directory.appendingPathComponent("xdiary-data.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = DiaryDefaults.dailyReviewTemplate
        var draft = original
        draft.name = "未保存的模板名称"

        try TemplateDraftRecoveryStore.sync(draft: draft, original: original, dataURL: dataURL)

        let restored = try TemplateDraftRecoveryStore.restore(for: dataURL)
        let recovered = try #require(restored)
        #expect(recovered.draft == draft)
        #expect(recovered.original == original)
    }

    @Test("保存或放弃修改后会移除模板恢复文件")
    func cleanDraftRemovesRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dataURL = directory.appendingPathComponent("xdiary-data.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = DiaryDefaults.dailyReviewTemplate
        var dirty = original
        dirty.name = "临时名称"
        try TemplateDraftRecoveryStore.sync(draft: dirty, original: original, dataURL: dataURL)
        #expect(try TemplateDraftRecoveryStore.restore(for: dataURL) != nil)

        try TemplateDraftRecoveryStore.sync(draft: original, original: original, dataURL: dataURL)
        #expect(try TemplateDraftRecoveryStore.restore(for: dataURL) == nil)
    }
}
