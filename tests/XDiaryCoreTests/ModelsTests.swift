import Foundation
import XCTest
@testable import XDiaryCore

final class ModelsTests: XCTestCase {
    func testDefaultTemplatesContainScreenshotQuestionsTomorrowAndSeparateFreeWriting() {
        let template = DiaryDefaults.dailyReviewTemplate
        let labels = template.blocks.map(\.displayText)

        XCTAssertEqual(template.name, "每日复盘")
        XCTAssertEqual(labels.first, "【日期】")
        XCTAssertTrue(labels.contains("1. 今天发生了什么？"))
        XCTAssertTrue(labels.contains("2. 今天什么事情让我产生了明显情绪？"))
        XCTAssertTrue(labels.contains("事情"))
        XCTAssertTrue(labels.contains("情绪"))
        XCTAssertTrue(labels.contains("强度"))
        XCTAssertTrue(labels.contains("3. 我当时脑子里的解释是什么？"))
        XCTAssertTrue(labels.contains("事实"))
        XCTAssertTrue(labels.contains("推测"))
        XCTAssertTrue(labels.contains("4. 这件事真正影响我的是什么？"))
        XCTAssertTrue(labels.contains("5. 我今天有没有做出一个更成熟的选择？"))
        XCTAssertTrue(labels.contains("6. 我今天为长期目标做了什么？"))
        XCTAssertTrue(labels.contains("7. 今天有什么让我觉得还不错？"))
        XCTAssertTrue(labels.contains("【明天只做一件事】"))
        XCTAssertFalse(labels.contains("【自由书写】"))
        XCTAssertEqual(labels.last, "明天最重要的一件事")

        let initialData = DiaryDefaults.initialData(now: fixedDate())
        XCTAssertEqual(initialData.templates.map(\.id), [DiaryDefaults.dailyReviewTemplateID, DiaryDefaults.freeWritingTemplateID])
        XCTAssertEqual(DiaryDefaults.freeWritingTemplate.name, "自由书写")
        XCTAssertEqual(DiaryDefaults.freeWritingTemplate.blocks.count, 1)
        XCTAssertEqual(DiaryDefaults.freeWritingTemplate.blocks.first?.kind, .textArea)

        let strength = template.blocks.first { $0.displayText == "强度" }
        guard case let .rating(_, _, unit, min, max, step) = strength else {
            return XCTFail("强度应为评分字段")
        }
        XCTAssertEqual(unit, "/10")
        XCTAssertEqual(min, 0)
        XCTAssertEqual(max, 10)
        XCTAssertEqual(step, 1)
    }

    func testCreateEntryCopiesTemplateAndInitializesEveryInputToNull() throws {
        let template = makeTemplate()
        var data = makeData(template: template)

        let entry = try data.createEntry(
            on: "2026-09-11",
            templateID: template.id,
            now: fixedDate(1_789_056_100)
        )

        XCTAssertEqual(data.entries, [entry])
        XCTAssertEqual(entry.date, "2026-09-11")
        XCTAssertEqual(entry.template.sourceTemplateID, template.id)
        XCTAssertEqual(entry.template.name, template.name)
        XCTAssertEqual(entry.template.blocks, template.blocks)
        XCTAssertEqual(entry.answers.count, template.blocks.filter(\.isInput).count)
        for block in template.blocks where block.isInput {
            XCTAssertEqual(entry.answers[block.id], .null)
        }
    }

    func testHistoricalEntryKeepsSnapshotAfterTemplateChanges() throws {
        let original = makeTemplate(name: "原模板")
        var data = makeData(template: original)
        let entry = try data.createEntry(on: "2026-09-11", templateID: original.id, now: fixedDate())

        data.templates[0].name = "修改后的模板"
        data.templates[0].blocks = [.textArea(prompt: "新问题", placeholder: nil)]

        XCTAssertEqual(entry.template.name, "原模板")
        XCTAssertEqual(entry.template.blocks, original.blocks)
        XCTAssertEqual(data.entries[0].template.name, "原模板")
        XCTAssertEqual(data.entries[0].template.blocks, original.blocks)
    }

    func testCreateEntryRejectsDuplicateDateAndMissingTemplate() throws {
        let template = makeTemplate()
        var data = makeData(template: template)
        _ = try data.createEntry(on: "2026-09-11", templateID: template.id, now: fixedDate())

        XCTAssertThrowsError(
            try data.createEntry(on: "2026-09-11", templateID: template.id, now: fixedDate())
        ) { error in
            guard case XDiaryError.entryAlreadyExists("2026-09-11") = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
        XCTAssertThrowsError(
            try data.createEntry(on: "2026-09-12", templateID: UUID(), now: fixedDate())
        ) { error in
            guard case XDiaryError.templateNotFound = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
    }

    func testAnswerValueCodableUsesJSONPrimitivesIncludingNull() throws {
        let values: [DiaryAnswerValue] = [.string("中文\n第二行"), .number(8.5), .null]
        let data = try JSONEncoder().encode(values)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])

        XCTAssertEqual(object[0] as? String, "中文\n第二行")
        XCTAssertEqual(object[1] as? Double, 8.5)
        XCTAssertTrue(object[2] is NSNull)
        XCTAssertEqual(try JSONDecoder().decode([DiaryAnswerValue].self, from: data), values)
    }
}
