import Foundation
import XCTest
@testable import XDiaryCore

final class BackupAndMergeTests: XCTestCase {
    func testFullBackupRoundTripPreservesChineseNewlinesNumbersAndNull() throws {
        let template = makeTemplate()
        var data = makeData(template: template)
        var entry = try data.createEntry(on: "2026-09-11", templateID: template.id, now: fixedDate())
        let inputs = template.blocks.filter(\.isInput)
        entry.answers[inputs[0].id] = .string("中文第一行\n中文第二行")
        entry.answers[inputs[1].id] = .null
        entry.answers[inputs[2].id] = .number(45)
        entry.answers[inputs[3].id] = .number(8)
        data.entries[0] = entry

        let encoded = try DiaryBackup.encode(data)
        let decoded = try DiaryBackup.decode(encoded)

        XCTAssertEqual(decoded, data)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertTrue(json.contains("中文第一行\\n中文第二行"))
        XCTAssertTrue(json.contains("\"schemaVersion\" : 1"))
    }

    func testDecodeRejectsUnsupportedVersionInvalidDateAndMissingDefaultTemplate() throws {
        var data = makeData()
        data.schemaVersion = 2
        XCTAssertThrowsError(try DiaryBackup.decode(try JSONEncoder().encode(data))) { error in
            guard case XDiaryError.unsupportedSchemaVersion(2) = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        data.schemaVersion = 1
        let template = data.templates[0]
        data.entries = [DiaryEntry(
            date: "2026-02-30",
            template: TemplateSnapshot(template: template, capturedAt: fixedDate()),
            answers: [:],
            createdAt: fixedDate(),
            updatedAt: fixedDate()
        )]
        XCTAssertThrowsError(try DiaryBackup.decode(try JSONEncoder().encode(data))) { error in
            guard case XDiaryError.invalidDate("2026-02-30") = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        data.entries = []
        data.defaultTemplateID = UUID()
        XCTAssertThrowsError(try DiaryBackup.decode(try JSONEncoder().encode(data))) { error in
            guard case XDiaryError.defaultTemplateMissing = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
    }

    func testValidationRejectsDuplicateTemplateEntryDateEntryIDAndBlockID() throws {
        let template = makeTemplate()
        var duplicatedTemplate = makeData(template: template)
        duplicatedTemplate.templates.append(template)
        XCTAssertThrowsError(try duplicatedTemplate.validate()) { error in
            guard case XDiaryError.duplicateTemplateID(template.id) = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        let snapshot = TemplateSnapshot(template: template, capturedAt: fixedDate())
        let sharedID = UUID()
        var duplicatedDate = makeData(template: template, entries: [
            DiaryEntry(id: sharedID, date: "2026-09-10", template: snapshot, answers: [:], createdAt: fixedDate(), updatedAt: fixedDate()),
            DiaryEntry(date: "2026-09-10", template: snapshot, answers: [:], createdAt: fixedDate(), updatedAt: fixedDate()),
        ])
        XCTAssertThrowsError(try duplicatedDate.validate()) { error in
            guard case XDiaryError.duplicateEntryDate("2026-09-10") = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        duplicatedDate.entries[1].date = "2026-09-11"
        duplicatedDate.entries[1].id = sharedID
        XCTAssertThrowsError(try duplicatedDate.validate()) { error in
            guard case XDiaryError.duplicateEntryID(sharedID) = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        let block = TemplateBlock.text(prompt: "问题", placeholder: nil)
        var duplicateBlocks = makeTemplate(blocks: [block, block])
        duplicateBlocks.updatedAt = fixedDate(1_789_056_200)
        XCTAssertThrowsError(try makeData(template: duplicateBlocks).validate()) { error in
            guard case XDiaryError.duplicateBlockID(block.id) = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
    }

    func testValidationRejectsInvalidHeadingAndNumericConfiguration() {
        let badHeading = makeTemplate(blocks: [.heading(level: 4, title: "层级错误")])
        XCTAssertThrowsError(try makeData(template: badHeading).validate()) { error in
            guard case XDiaryError.invalidBlock = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        let badNumber = makeTemplate(blocks: [
            .number(prompt: "数值", unit: nil, min: 10, max: 1, step: 0),
        ])
        XCTAssertThrowsError(try makeData(template: badNumber).validate()) { error in
            guard case XDiaryError.invalidBlock = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
    }

    func testValidationRejectsUnknownOrWrongTypeAnswer() throws {
        let template = makeTemplate()
        var data = makeData(template: template)
        var entry = try data.createEntry(on: "2026-09-11", templateID: template.id, now: fixedDate())
        entry.answers[UUID()] = .string("幽灵字段")
        data.entries = [entry]
        XCTAssertThrowsError(try data.validate()) { error in
            guard case XDiaryError.invalidAnswer = error else {
                return XCTFail("意外错误：\(error)")
            }
        }

        let numberBlock = template.blocks.first { $0.kind == .number }!
        entry.answers.removeAll()
        entry.answers[numberBlock.id] = .string("不是数字")
        data.entries = [entry]
        XCTAssertThrowsError(try data.validate()) { error in
            guard case XDiaryError.invalidAnswer = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
    }

    func testMergeKeepLocalAndUseImportResolveTemplateAndDateConflicts() throws {
        let templateID = UUID()
        let localTemplate = makeTemplate(id: templateID, name: "本地模板")
        let importedTemplate = makeTemplate(id: templateID, name: "导入模板")
        var local = makeData(template: localTemplate)
        var incoming = makeData(template: importedTemplate)
        var localEntry = try local.createEntry(on: "2026-09-11", templateID: templateID, now: fixedDate())
        localEntry.answers[localTemplate.blocks.first(where: \.isInput)!.id] = .string("本地回答")
        local.entries = [localEntry]
        var importedEntry = try incoming.createEntry(on: "2026-09-11", templateID: templateID, now: fixedDate(1_789_056_500))
        importedEntry.answers[importedTemplate.blocks.first(where: \.isInput)!.id] = .string("导入回答")
        incoming.entries = [importedEntry]

        let kept = try DiaryImporter.merge(local: local, incoming: incoming, strategy: .keepLocal)
        XCTAssertEqual(kept.templates.first?.name, "本地模板")
        XCTAssertEqual(kept.entries.first?.answers[localTemplate.blocks.first(where: \.isInput)!.id], .string("本地回答"))
        XCTAssertEqual(kept.id, local.id)

        let replaced = try DiaryImporter.merge(local: local, incoming: incoming, strategy: .useImport)
        XCTAssertEqual(replaced.templates.first?.name, "导入模板")
        XCTAssertEqual(replaced.entries.first?.answers[importedTemplate.blocks.first(where: \.isInput)!.id], .string("导入回答"))
        XCTAssertEqual(replaced.id, local.id)
    }

    func testMergeAddsNonConflictingTemplatesAndEntries() throws {
        let localTemplate = makeTemplate(name: "本地")
        let importedTemplate = makeTemplate(name: "导入")
        var local = makeData(template: localTemplate)
        var incoming = makeData(template: importedTemplate)
        _ = try local.createEntry(on: "2026-09-10", templateID: localTemplate.id, now: fixedDate())
        _ = try incoming.createEntry(on: "2026-09-11", templateID: importedTemplate.id, now: fixedDate())

        let merged = try DiaryImporter.merge(local: local, incoming: incoming, strategy: .keepLocal)

        XCTAssertEqual(Set(merged.templates.map(\.id)), [localTemplate.id, importedTemplate.id])
        XCTAssertEqual(Set(merged.entries.map(\.date)), ["2026-09-10", "2026-09-11"])
        XCTAssertEqual(merged.defaultTemplateID, localTemplate.id)
    }
}
