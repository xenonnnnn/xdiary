import Foundation

public enum DiaryMarkdownExporter {
    public static func export(
        _ data: DiaryData,
        from startDate: String? = nil,
        through endDate: String? = nil
    ) throws -> String {
        try data.validate()
        let calendar = DiaryCalendar(timeZone: .gmt)
        if let startDate { try calendar.validate(startDate) }
        if let endDate { try calendar.validate(endDate) }
        if let startDate, let endDate, startDate > endDate {
            throw XDiaryError.invalidDateRange
        }

        let entries = data.entries
            .filter { entry in
                (startDate.map { entry.date >= $0 } ?? true)
                    && (endDate.map { entry.date <= $0 } ?? true)
            }
            .sorted { $0.date < $1.date }

        var sections = ["# xdiary 日记导出"]
        var metadata: [String] = []
        if let startDate { metadata.append("- 开始日期：\(startDate)") }
        if let endDate { metadata.append("- 结束日期：\(endDate)") }
        metadata.append("- 日记数量：\(entries.count)")
        sections.append(metadata.joined(separator: "\n"))
        sections.append(contentsOf: entries.map(markdown(for:)))
        return sections.joined(separator: "\n\n") + "\n"
    }

    private static func markdown(for entry: DiaryEntry) -> String {
        var sections = ["## \(entry.date)", "- 模板：\(entry.template.name)"]
        for block in entry.template.blocks {
            switch block {
            case let .heading(_, level, title):
                sections.append("\(String(repeating: "#", count: level + 2)) \(title)")
            case let .text(id, prompt, _), let .textArea(id, prompt, _):
                sections.append(textField(prompt: prompt, answer: entry.answers[id] ?? .null))
            case let .number(id, prompt, unit, min, max, step):
                sections.append(numberField(
                    prompt: prompt,
                    answer: entry.answers[id] ?? .null,
                    unit: unit,
                    min: min,
                    max: max,
                    step: step,
                    scaleLabel: "量纲"
                ))
            case let .rating(id, prompt, unit, min, max, step):
                sections.append(numberField(
                    prompt: prompt,
                    answer: entry.answers[id] ?? .null,
                    unit: unit,
                    min: min,
                    max: max,
                    step: step,
                    scaleLabel: "评分范围",
                    includeUnitInScale: false
                ))
            }
        }
        return sections.joined(separator: "\n\n")
    }

    private static func textField(prompt: String, answer: DiaryAnswerValue) -> String {
        let question = "**问题：** \(prompt)"
        switch answer {
        case let .string(value) where value.isEmpty:
            return "\(question)\n\n**回答：** （空字符串）"
        case let .string(value):
            return "\(question)\n\n**回答：**\n\(value)"
        case .null:
            return "\(question)\n\n**回答：** （未填写）"
        case let .number(value):
            return "\(question)\n\n**回答：** \(format(value))"
        }
    }

    private static func numberField(
        prompt: String,
        answer: DiaryAnswerValue,
        unit: String?,
        min: Double?,
        max: Double?,
        step: Double?,
        scaleLabel: String,
        includeUnitInScale: Bool = true
    ) -> String {
        var lines = ["**问题：** \(prompt)"]
        switch answer {
        case let .number(value):
            lines.append("**回答：** \(format(value))\(formattedUnit(unit))")
        case .null:
            lines.append("**回答：** （未填写）")
        case let .string(value):
            lines.append("**回答：** \(value.isEmpty ? "（空字符串）" : value)")
        }

        var dimensions: [String] = []
        if let min { dimensions.append("最小 \(format(min))") }
        if let max { dimensions.append("最大 \(format(max))") }
        if let step { dimensions.append("步长 \(format(step))") }
        if includeUnitInScale, let unit, !unit.isEmpty { dimensions.append("单位 \(unit)") }
        if !dimensions.isEmpty {
            lines.append("**\(scaleLabel)：** \(dimensions.joined(separator: "，"))")
        }
        return lines.joined(separator: "\n\n")
    }

    private static func formattedUnit(_ unit: String?) -> String {
        guard let unit, !unit.isEmpty else { return "" }
        return " \(unit)"
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        return String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
