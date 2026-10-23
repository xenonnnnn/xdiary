import Foundation
@testable import XDiaryCore

func fixedDate(_ seconds: TimeInterval = 1_789_056_000) -> Date {
    Date(timeIntervalSince1970: seconds)
}

func makeTemplate(
    id: UUID = UUID(),
    name: String = "测试模板",
    blocks: [TemplateBlock]? = nil
) -> DiaryTemplate {
    DiaryTemplate(
        id: id,
        name: name,
        blocks: blocks ?? [
            .heading(level: 1, title: "复盘"),
            .text(prompt: "一句话", placeholder: "写点什么"),
            .textArea(prompt: "详细记录", placeholder: nil),
            .number(prompt: "专注时长", unit: "分钟", min: 0, max: 1_440, step: 1),
            .rating(prompt: "今日评分", unit: "分", min: 1, max: 10, step: 1),
        ],
        createdAt: fixedDate(),
        updatedAt: fixedDate()
    )
}

func makeData(
    template: DiaryTemplate? = nil,
    entries: [DiaryEntry] = []
) -> DiaryData {
    let template = template ?? makeTemplate()
    return DiaryData(
        id: UUID(),
        schemaVersion: 1,
        templates: [template],
        entries: entries,
        defaultTemplateID: template.id
    )
}
