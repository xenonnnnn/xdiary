import Foundation
import Testing
import XDiaryCore
@testable import xdiary

@MainActor
struct AppStoreTests {
    private func temporaryDataURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("xdiary-app-store-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("xdiary-data.json")
    }

    @Test("第一次填写会创建当天日记并保存")
    func firstAnswerCreatesAndPersistsEntry() throws {
        let url = try temporaryDataURL()
        let date = Date(timeIntervalSince1970: 1_789_063_200)
        let store = try AppStore(dataURL: url, now: { date })
        let eventsID = try #require(store.activeBlocks.first(where: \.isInput)?.id)

        #expect(store.data.entries.isEmpty)
        try store.setAnswer(.string("完成了原生 xdiary"), for: eventsID)

        #expect(store.selectedEntry?.answers[eventsID] == .string("完成了原生 xdiary"))
        #expect(store.saveState == .saved)
        let loaded = try DiaryFileStore().load(from: url)
        #expect(loaded.entries.first?.answers[eventsID] == .string("完成了原生 xdiary"))
    }

    @Test("日期切换后能回到原日记")
    func dateNavigationKeepsAnswers() throws {
        let store = try AppStore(dataURL: temporaryDataURL(), now: { Date(timeIntervalSince1970: 1_789_063_200) })
        let eventsID = try #require(store.activeBlocks.first(where: \.isInput)?.id)
        let original = store.selectedDate
        try store.setAnswer(.string("今天"), for: eventsID)
        store.moveSelection(byDays: -1)
        #expect(store.selectedEntry == nil)
        store.selectDate(original)
        #expect(store.selectedEntry?.answers[eventsID] == .string("今天"))
    }

    @Test("左侧月份只显示有日记的月份")
    func availableMonthsOnlyContainsMonthsWithEntries() throws {
        let store = try AppStore(dataURL: temporaryDataURL(), now: Date.init)
        let eventsID = try #require(store.activeBlocks.first(where: \.isInput)?.id)

        #expect(store.availableMonths().isEmpty)

        store.selectDate("2026-07-03")
        try store.setAnswer(.string("七月日记"), for: eventsID)
        store.selectDate("2026-09-11")
        try store.setAnswer(.string("九月日记"), for: eventsID)

        #expect(store.availableMonths() == ["2026-09", "2026-07"])

        try store.deleteSelectedEntry()
        #expect(store.availableMonths() == ["2026-07"])
    }

    @Test("连续输入先保留在内存，刷新时一次写入最终内容")
    func deferredAnswersFlushLatestValue() throws {
        let url = try temporaryDataURL()
        let store = try AppStore(dataURL: url, now: Date.init)
        let eventsID = try #require(store.activeBlocks.first(where: \.isInput)?.id)

        try store.setAnswerDeferred(.string("第一版"), for: eventsID)
        try store.setAnswerDeferred(.string("最终内容"), for: eventsID)

        #expect(store.selectedEntry?.answers[eventsID] == .string("最终内容"))
        #expect(!FileManager.default.fileExists(atPath: url.path))

        try store.flushPendingSave()
        let loaded = try DiaryFileStore().load(from: url)
        #expect(loaded.entries.first?.answers[eventsID] == .string("最终内容"))
        #expect(store.saveState == .saved)
    }

    @Test("保存失败保留内存里的文字并报告错误")
    func failedSaveKeepsDraft() throws {
        let parentFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("xdiary-parent-file-\(UUID().uuidString)")
        try Data("not a directory".utf8).write(to: parentFile)
        let impossibleURL = parentFile.appendingPathComponent("xdiary-data.json")
        let store = try AppStore(dataURL: impossibleURL, now: Date.init)
        let eventsID = try #require(store.activeBlocks.first(where: \.isInput)?.id)

        #expect(throws: (any Error).self) {
            try store.setAnswer(.string("不能丢失"), for: eventsID)
        }
        #expect(store.selectedEntry?.answers[eventsID] == .string("不能丢失"))
        if case .failed = store.saveState {
            // Expected.
        } else {
            Issue.record("保存失败必须显示 failed 状态")
        }
    }

    @Test("导入合并后立即落盘")
    func importPersistsMergedData() throws {
        let url = try temporaryDataURL()
        let store = try AppStore(dataURL: url, now: Date.init)
        var incoming = DiaryDefaults.initialData()
        let templateID = try #require(incoming.defaultTemplateID)
        try incoming.createEntry(on: "2026-09-10", templateID: templateID)

        try store.importData(incoming, strategy: .useImport)

        #expect(store.data.entries.contains { $0.date == "2026-09-10" })
        let loaded = try DiaryFileStore().load(from: url)
        #expect(loaded.entries.contains { $0.date == "2026-09-10" })
    }

    @Test("导入预览把相同日记 ID 视为冲突")
    func importPreviewTreatsMatchingEntryIDAsConflict() throws {
        let url = try temporaryDataURL()
        var local = DiaryDefaults.initialData()
        let templateID = try #require(local.defaultTemplateID)
        let localEntry = try local.createEntry(on: "2026-09-10", templateID: templateID)
        try DiaryFileStore().save(local, to: url)
        let store = try AppStore(dataURL: url, now: Date.init)

        var incoming = DiaryDefaults.initialData()
        var importedEntry = try incoming.createEntry(on: "2026-09-11", templateID: templateID)
        importedEntry.id = localEntry.id
        incoming.entries = [importedEntry]

        let preview = store.importPreview(for: incoming)

        #expect(preview.newEntries == 0)
        #expect(preview.entryConflicts == 1)
    }

    @Test("导入记录同时冲突日期和 ID 时准确统计受影响的本机日记")
    func importPreviewCountsEveryAffectedLocalEntry() throws {
        let url = try temporaryDataURL()
        var local = DiaryDefaults.initialData()
        let templateID = try #require(local.defaultTemplateID)
        let first = try local.createEntry(on: "2026-09-10", templateID: templateID)
        let second = try local.createEntry(on: "2026-09-11", templateID: templateID)
        try DiaryFileStore.save(local, to: url)
        let store = try AppStore(dataURL: url, now: Date.init)

        var incoming = DiaryDefaults.initialData()
        var crossConflict = try incoming.createEntry(on: first.date, templateID: templateID)
        crossConflict.id = second.id
        incoming.entries = [crossConflict]

        let preview = store.importPreview(for: incoming)

        #expect(preview.entryConflicts == 1)
        #expect(preview.newEntries == 0)
        #expect(preview.affectedLocalEntries == 2)
    }

    @Test("模板至少需要一个可填写字段")
    func rejectsHeadingOnlyTemplate() throws {
        let store = try AppStore(dataURL: temporaryDataURL(), now: Date.init)
        let template = DiaryTemplate(name: "只有标题", blocks: [
            .heading(level: 1, title: "无法填写")
        ])

        #expect(throws: (any Error).self) {
            try store.saveTemplate(template)
        }
        #expect(!store.data.templates.contains { $0.id == template.id })
    }
}
