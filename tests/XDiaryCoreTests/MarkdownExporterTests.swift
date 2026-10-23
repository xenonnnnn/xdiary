import Foundation
import XCTest
@testable import XDiaryCore

final class MarkdownExporterTests: XCTestCase {
    func testMarkdownIsDateSortedRangeFilteredAndAIReadable() throws {
        let heading = TemplateBlock.heading(level: 1, title: "【状态】")
        let note = TemplateBlock.textArea(prompt: "今天发生了什么？", placeholder: nil)
        let duration = TemplateBlock.number(prompt: "专注时长", unit: "分钟", min: 0, max: 600, step: 5)
        let rating = TemplateBlock.rating(prompt: "情绪强度", unit: "/10", min: 0, max: 10, step: 1)
        let empty = TemplateBlock.text(prompt: "补充", placeholder: nil)
        let template = makeTemplate(blocks: [heading, note, duration, rating, empty])
        let snapshot = TemplateSnapshot(template: template, capturedAt: fixedDate())
        let earlier = DiaryEntry(
            date: "2026-09-09",
            template: snapshot,
            answers: [note.id: .string("不在范围")],
            createdAt: fixedDate(),
            updatedAt: fixedDate()
        )
        let later = DiaryEntry(
            date: "2026-09-11",
            template: snapshot,
            answers: [note.id: .string("第二天")],
            createdAt: fixedDate(),
            updatedAt: fixedDate()
        )
        let first = DiaryEntry(
            date: "2026-09-10",
            template: snapshot,
            answers: [
                note.id: .string("中文第一行\n中文第二行"),
                duration.id: .number(45),
                rating.id: .number(8),
                empty.id: .null,
            ],
            createdAt: fixedDate(),
            updatedAt: fixedDate()
        )
        let data = makeData(template: template, entries: [later, earlier, first])

        let markdown = try DiaryMarkdownExporter.export(
            data,
            from: "2026-09-10",
            through: "2026-09-11"
        )

        XCTAssertTrue(markdown.hasPrefix("# xdiary 日记导出"))
        XCTAssertFalse(markdown.contains("2026-09-09"))
        XCTAssertLessThan(
            try XCTUnwrap(markdown.range(of: "## 2026-09-10")?.lowerBound),
            try XCTUnwrap(markdown.range(of: "## 2026-09-11")?.lowerBound)
        )
        XCTAssertTrue(markdown.contains("### 【状态】"))
        XCTAssertTrue(markdown.contains("**问题：** 今天发生了什么？"))
        XCTAssertTrue(markdown.contains("中文第一行\n中文第二行"))
        XCTAssertTrue(markdown.contains("**回答：** 45 分钟"))
        XCTAssertTrue(markdown.contains("**量纲：** 最小 0，最大 600，步长 5，单位 分钟"))
        XCTAssertTrue(markdown.contains("**回答：** 8 /10"))
        XCTAssertTrue(markdown.contains("**评分范围：** 最小 0，最大 10，步长 1"))
        XCTAssertTrue(markdown.contains("**回答：** （未填写）"))
        XCTAssertFalse(markdown.contains(note.id.uuidString))
    }

    func testMarkdownRejectsReversedOrInvalidRange() {
        let data = makeData()

        XCTAssertThrowsError(try DiaryMarkdownExporter.export(data, from: "2026-09-12", through: "2026-09-11")) { error in
            guard case XDiaryError.invalidDateRange = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
        XCTAssertThrowsError(try DiaryMarkdownExporter.export(data, from: "2026-9-1", through: nil)) { error in
            guard case XDiaryError.invalidDate("2026-9-1") = error else {
                return XCTFail("意外错误：\(error)")
            }
        }
    }
}
