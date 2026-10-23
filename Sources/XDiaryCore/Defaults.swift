import Foundation

public enum DiaryDefaults {
    public static let dailyReviewTemplateID = UUID(uuidString: "5840B9BB-D84C-4F46-B358-201C871E35BF")!
    public static let freeWritingTemplateID = UUID(uuidString: "C4804E67-3238-4A60-A029-1A4E2553A935")!

    public static var dailyReviewTemplate: DiaryTemplate {
        DiaryTemplate(
            id: dailyReviewTemplateID,
            name: "每日复盘",
            blocks: [
                .heading(id: blockID(1), level: 1, title: "【日期】"),
                .textArea(id: blockID(2), prompt: "1. 今天发生了什么？", placeholder: "记录今天发生的事"),
                .heading(id: blockID(3), level: 2, title: "2. 今天什么事情让我产生了明显情绪？"),
                .textArea(id: blockID(4), prompt: "事情", placeholder: "发生了什么"),
                .text(id: blockID(5), prompt: "情绪", placeholder: "例如：开心、焦虑、委屈"),
                .rating(id: blockID(6), prompt: "强度", unit: "/10", min: 0, max: 10, step: 1),
                .heading(id: blockID(7), level: 2, title: "3. 我当时脑子里的解释是什么？"),
                .textArea(id: blockID(8), prompt: "事实", placeholder: "只写可以被观察到的事实"),
                .textArea(id: blockID(9), prompt: "推测", placeholder: "写下当时的解释或推测"),
                .textArea(id: blockID(10), prompt: "4. 这件事真正影响我的是什么？", placeholder: nil),
                .textArea(id: blockID(11), prompt: "5. 我今天有没有做出一个更成熟的选择？", placeholder: nil),
                .textArea(id: blockID(12), prompt: "6. 我今天为长期目标做了什么？", placeholder: nil),
                .textArea(id: blockID(13), prompt: "7. 今天有什么让我觉得还不错？", placeholder: nil),
                .heading(id: blockID(14), level: 1, title: "【明天只做一件事】"),
                .textArea(id: blockID(15), prompt: "明天最重要的一件事", placeholder: "只写一件事"),
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    public static var freeWritingTemplate: DiaryTemplate {
        DiaryTemplate(
            id: freeWritingTemplateID,
            name: "自由书写",
            blocks: [
                .textArea(id: blockID(16), prompt: "自由记录", placeholder: "写下此刻想记录的内容"),
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    public static func initialData(now: Date = Date()) -> DiaryData {
        var template = dailyReviewTemplate
        template.createdAt = now
        template.updatedAt = now
        var freeWriting = freeWritingTemplate
        freeWriting.createdAt = now
        freeWriting.updatedAt = now
        return DiaryData(
            templates: [template, freeWriting],
            entries: [],
            defaultTemplateID: template.id
        )
    }

    private static func blockID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", value))!
    }
}
