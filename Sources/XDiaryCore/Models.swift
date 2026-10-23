import Foundation

public enum TemplateBlock: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case heading
        case text
        case textArea = "textarea"
        case number
        case rating
    }

    case heading(id: UUID = UUID(), level: Int, title: String)
    case text(id: UUID = UUID(), prompt: String, placeholder: String?)
    case textArea(id: UUID = UUID(), prompt: String, placeholder: String?)
    case number(
        id: UUID = UUID(),
        prompt: String,
        unit: String?,
        min: Double?,
        max: Double?,
        step: Double?
    )
    case rating(
        id: UUID = UUID(),
        prompt: String,
        unit: String?,
        min: Double,
        max: Double,
        step: Double
    )

    public var id: UUID {
        switch self {
        case let .heading(id, _, _),
             let .text(id, _, _),
             let .textArea(id, _, _),
             let .number(id, _, _, _, _, _),
             let .rating(id, _, _, _, _, _):
            id
        }
    }

    public var kind: Kind {
        switch self {
        case .heading: .heading
        case .text: .text
        case .textArea: .textArea
        case .number: .number
        case .rating: .rating
        }
    }

    public var isInput: Bool { kind != .heading }

    public var displayText: String {
        switch self {
        case let .heading(_, _, title): title
        case let .text(_, prompt, _),
             let .textArea(_, prompt, _),
             let .number(_, prompt, _, _, _, _),
             let .rating(_, prompt, _, _, _, _):
            prompt
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case level
        case title
        case prompt
        case placeholder
        case unit
        case min
        case max
        case step
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let type = try container.decode(Kind.self, forKey: .type)

        switch type {
        case .heading:
            self = .heading(
                id: id,
                level: try container.decode(Int.self, forKey: .level),
                title: try container.decode(String.self, forKey: .title)
            )
        case .text:
            self = .text(
                id: id,
                prompt: try container.decode(String.self, forKey: .prompt),
                placeholder: try container.decodeIfPresent(String.self, forKey: .placeholder)
            )
        case .textArea:
            self = .textArea(
                id: id,
                prompt: try container.decode(String.self, forKey: .prompt),
                placeholder: try container.decodeIfPresent(String.self, forKey: .placeholder)
            )
        case .number:
            self = .number(
                id: id,
                prompt: try container.decode(String.self, forKey: .prompt),
                unit: try container.decodeIfPresent(String.self, forKey: .unit),
                min: try container.decodeIfPresent(Double.self, forKey: .min),
                max: try container.decodeIfPresent(Double.self, forKey: .max),
                step: try container.decodeIfPresent(Double.self, forKey: .step)
            )
        case .rating:
            self = .rating(
                id: id,
                prompt: try container.decode(String.self, forKey: .prompt),
                unit: try container.decodeIfPresent(String.self, forKey: .unit),
                min: try container.decode(Double.self, forKey: .min),
                max: try container.decode(Double.self, forKey: .max),
                step: try container.decode(Double.self, forKey: .step)
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .type)

        switch self {
        case let .heading(_, level, title):
            try container.encode(level, forKey: .level)
            try container.encode(title, forKey: .title)
        case let .text(_, prompt, placeholder), let .textArea(_, prompt, placeholder):
            try container.encode(prompt, forKey: .prompt)
            try container.encodeIfPresent(placeholder, forKey: .placeholder)
        case let .number(_, prompt, unit, min, max, step):
            try container.encode(prompt, forKey: .prompt)
            try container.encodeIfPresent(unit, forKey: .unit)
            try container.encodeIfPresent(min, forKey: .min)
            try container.encodeIfPresent(max, forKey: .max)
            try container.encodeIfPresent(step, forKey: .step)
        case let .rating(_, prompt, unit, min, max, step):
            try container.encode(prompt, forKey: .prompt)
            try container.encodeIfPresent(unit, forKey: .unit)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
            try container.encode(step, forKey: .step)
        }
    }
}

public struct DiaryTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var blocks: [TemplateBlock]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        blocks: [TemplateBlock],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.blocks = blocks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TemplateSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sourceTemplateID: UUID
    public var name: String
    public var blocks: [TemplateBlock]
    public var capturedAt: Date

    public init(
        id: UUID = UUID(),
        sourceTemplateID: UUID,
        name: String,
        blocks: [TemplateBlock],
        capturedAt: Date
    ) {
        self.id = id
        self.sourceTemplateID = sourceTemplateID
        self.name = name
        self.blocks = blocks
        self.capturedAt = capturedAt
    }

    public init(id: UUID = UUID(), template: DiaryTemplate, capturedAt: Date = Date()) {
        self.init(
            id: id,
            sourceTemplateID: template.id,
            name: template.name,
            blocks: template.blocks,
            capturedAt: capturedAt
        )
    }
}

public enum DiaryAnswerValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case null

    public var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    public var numberValue: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "日记回答必须是字符串、数字或 null"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public struct DiaryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: String
    public var template: TemplateSnapshot
    public var answers: [UUID: DiaryAnswerValue]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: String,
        template: TemplateSnapshot,
        answers: [UUID: DiaryAnswerValue],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.template = template
        self.answers = answers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case template
        case answers
        case createdAt
        case updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        template = try container.decode(TemplateSnapshot.self, forKey: .template)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        let encodedAnswers = try container.decode([String: DiaryAnswerValue].self, forKey: .answers)
        var decodedAnswers: [UUID: DiaryAnswerValue] = [:]
        decodedAnswers.reserveCapacity(encodedAnswers.count)
        for (key, value) in encodedAnswers {
            guard let id = UUID(uuidString: key), id.uuidString.lowercased() == key.lowercased() else {
                throw DecodingError.dataCorruptedError(
                    forKey: .answers,
                    in: container,
                    debugDescription: "回答字段键不是有效 UUID：\(key)"
                )
            }
            decodedAnswers[id] = value
        }
        answers = decodedAnswers
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(template, forKey: .template)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        let encodedAnswers = Dictionary(uniqueKeysWithValues: answers.map { ($0.key.uuidString, $0.value) })
        try container.encode(encodedAnswers, forKey: .answers)
    }
}

public struct DiaryData: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var schemaVersion: Int
    public var templates: [DiaryTemplate]
    public var entries: [DiaryEntry]
    public var defaultTemplateID: UUID?

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = DiaryBackup.currentSchemaVersion,
        templates: [DiaryTemplate],
        entries: [DiaryEntry],
        defaultTemplateID: UUID?
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.templates = templates
        self.entries = entries
        self.defaultTemplateID = defaultTemplateID
    }
}
