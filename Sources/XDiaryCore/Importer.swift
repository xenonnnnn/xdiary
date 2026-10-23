import Foundation

public enum ImportConflictStrategy: String, Codable, CaseIterable, Sendable {
    case keepLocal
    case useImport
}

public enum DiaryImporter {
    public static func entriesConflict(_ local: DiaryEntry, _ incoming: DiaryEntry) -> Bool {
        local.date == incoming.date || local.id == incoming.id
    }

    public static func merge(
        local: DiaryData,
        incoming: DiaryData,
        strategy: ImportConflictStrategy
    ) throws -> DiaryData {
        try local.validate()
        try incoming.validate()

        var templates = local.templates
        for template in incoming.templates {
            if let index = templates.firstIndex(where: { $0.id == template.id }) {
                if strategy == .useImport { templates[index] = template }
            } else {
                templates.append(template)
            }
        }

        var entries = local.entries
        for entry in incoming.entries {
            let conflictIndexes = entries.indices.filter {
                entriesConflict(entries[$0], entry)
            }
            if conflictIndexes.isEmpty {
                entries.append(entry)
            } else if strategy == .useImport {
                for index in conflictIndexes.reversed() { entries.remove(at: index) }
                entries.append(entry)
            }
        }
        entries.sort { $0.date < $1.date }

        let result = DiaryData(
            id: local.id,
            schemaVersion: DiaryBackup.currentSchemaVersion,
            templates: templates,
            entries: entries,
            defaultTemplateID: strategy == .keepLocal
                ? local.defaultTemplateID
                : incoming.defaultTemplateID
        )
        try result.validate()
        return result
    }
}
