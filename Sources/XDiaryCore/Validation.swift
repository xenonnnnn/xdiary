import Foundation

public extension DiaryData {
    @discardableResult
    mutating func createEntry(
        on date: String,
        templateID: UUID,
        now: Date = Date()
    ) throws -> DiaryEntry {
        try DiaryCalendar(timeZone: .gmt).validate(date)
        guard !entries.contains(where: { $0.date == date }) else {
            throw XDiaryError.entryAlreadyExists(date)
        }
        guard let template = templates.first(where: { $0.id == templateID }) else {
            throw XDiaryError.templateNotFound(templateID)
        }
        let answers = Dictionary(
            uniqueKeysWithValues: template.blocks.compactMap { block in
                block.isInput ? (block.id, DiaryAnswerValue.null) : nil
            }
        )
        let entry = DiaryEntry(
            date: date,
            template: TemplateSnapshot(template: template, capturedAt: now),
            answers: answers,
            createdAt: now,
            updatedAt: now
        )
        entries.append(entry)
        return entry
    }

    func validate() throws {
        guard schemaVersion == DiaryBackup.currentSchemaVersion else {
            throw XDiaryError.unsupportedSchemaVersion(schemaVersion)
        }

        var templateIDs = Set<UUID>()
        for template in templates {
            guard templateIDs.insert(template.id).inserted else {
                throw XDiaryError.duplicateTemplateID(template.id)
            }
            try validateTemplate(
                id: template.id,
                name: template.name,
                blocks: template.blocks
            )
        }
        if let defaultTemplateID, !templateIDs.contains(defaultTemplateID) {
            throw XDiaryError.defaultTemplateMissing(defaultTemplateID)
        }

        var entryIDs = Set<UUID>()
        var entryDates = Set<String>()
        let diaryCalendar = DiaryCalendar(timeZone: .gmt)
        for entry in entries {
            try diaryCalendar.validate(entry.date)
            guard entryDates.insert(entry.date).inserted else {
                throw XDiaryError.duplicateEntryDate(entry.date)
            }
            guard entryIDs.insert(entry.id).inserted else {
                throw XDiaryError.duplicateEntryID(entry.id)
            }
            try validateTemplate(
                id: entry.template.id,
                name: entry.template.name,
                blocks: entry.template.blocks
            )
            try validateAnswers(in: entry)
        }
    }
}

private func validateTemplate(id: UUID, name: String, blocks: [TemplateBlock]) throws {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw XDiaryError.invalidTemplate(id, reason: "名称不能为空")
    }
    var blockIDs = Set<UUID>()
    for block in blocks {
        guard blockIDs.insert(block.id).inserted else {
            throw XDiaryError.duplicateBlockID(block.id)
        }
        try validateBlock(block)
    }
}

private func validateBlock(_ block: TemplateBlock) throws {
    guard !block.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw XDiaryError.invalidBlock(block.id, reason: "标题或问题不能为空")
    }
    switch block {
    case let .heading(_, level, _):
        guard (1...3).contains(level) else {
            throw XDiaryError.invalidBlock(block.id, reason: "标题层级必须为 1 到 3")
        }
    case .text, .textArea:
        break
    case let .number(_, _, _, min, max, step):
        try validateNumericConfiguration(blockID: block.id, min: min, max: max, step: step)
    case let .rating(_, _, _, min, max, step):
        try validateNumericConfiguration(blockID: block.id, min: min, max: max, step: step)
    }
}

private func validateNumericConfiguration(
    blockID: UUID,
    min: Double?,
    max: Double?,
    step: Double?
) throws {
    guard [min, max, step].compactMap({ $0 }).allSatisfy(\.isFinite) else {
        throw XDiaryError.invalidBlock(blockID, reason: "数值配置必须是有限数字")
    }
    if let min, let max, min > max {
        throw XDiaryError.invalidBlock(blockID, reason: "最小值不能大于最大值")
    }
    if let step, step <= 0 {
        throw XDiaryError.invalidBlock(blockID, reason: "步长必须大于 0")
    }
}

private func validateAnswers(in entry: DiaryEntry) throws {
    let blocks = Dictionary(uniqueKeysWithValues: entry.template.blocks.map { ($0.id, $0) })
    for (blockID, answer) in entry.answers {
        guard let block = blocks[blockID], block.isInput else {
            throw XDiaryError.invalidAnswer(
                entryID: entry.id,
                blockID: blockID,
                reason: "找不到对应的输入字段"
            )
        }
        switch (block.kind, answer) {
        case (_, .null), (.text, .string), (.textArea, .string):
            break
        case (.number, .number), (.rating, .number):
            guard let value = answer.numberValue, value.isFinite else {
                throw XDiaryError.invalidAnswer(entryID: entry.id, blockID: blockID, reason: "数字必须是有限值")
            }
            try validateNumericAnswer(value, block: block, entryID: entry.id)
        default:
            throw XDiaryError.invalidAnswer(
                entryID: entry.id,
                blockID: blockID,
                reason: "回答类型与字段类型不匹配"
            )
        }
    }
}

private func validateNumericAnswer(_ value: Double, block: TemplateBlock, entryID: UUID) throws {
    let min: Double?
    let max: Double?
    let step: Double?
    switch block {
    case let .number(_, _, _, configuredMin, configuredMax, configuredStep):
        (min, max, step) = (configuredMin, configuredMax, configuredStep)
    case let .rating(_, _, _, configuredMin, configuredMax, configuredStep):
        (min, max, step) = (configuredMin, configuredMax, configuredStep)
    default:
        return
    }
    if let min, value < min || (max.map { value > $0 } ?? false) {
        throw XDiaryError.invalidAnswer(entryID: entryID, blockID: block.id, reason: "数字超出范围")
    }
    if min == nil, let max, value > max {
        throw XDiaryError.invalidAnswer(entryID: entryID, blockID: block.id, reason: "数字超出范围")
    }
    if let step {
        let quotient = (value - (min ?? 0)) / step
        if abs(quotient - quotient.rounded()) > 1e-9 {
            throw XDiaryError.invalidAnswer(entryID: entryID, blockID: block.id, reason: "数字不符合步长")
        }
    }
}
