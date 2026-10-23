import Combine
import Foundation
import XDiaryCore

@MainActor
final class AppStore: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    enum Page: Equatable {
        case diary
        case templates
    }

    @Published private(set) var data: DiaryData
    @Published var selectedDate: String
    @Published var selectedTemplateID: UUID?
    @Published var page: Page = .diary
    @Published private(set) var saveState: SaveState = .idle

    let dataURL: URL
    let calendar: DiaryCalendar
    private let now: () -> Date
    private let fileStore: DiaryFileStore
    private var pendingAnswerSave: Task<Void, Never>?

    init(
        dataURL: URL = AppStore.defaultDataURL(),
        calendar: DiaryCalendar = DiaryCalendar(),
        now: @escaping () -> Date = Date.init,
        fileStore: DiaryFileStore = DiaryFileStore()
    ) throws {
        self.dataURL = dataURL
        self.calendar = calendar
        self.now = now
        self.fileStore = fileStore
        selectedDate = calendar.dateString(for: now())

        do {
            data = try fileStore.load(from: dataURL)
            saveState = .saved
        } catch XDiaryError.fileNotFound {
            data = DiaryDefaults.initialData(now: now())
        }
        selectedTemplateID = data.defaultTemplateID
    }

    static func defaultDataURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("xdiary", isDirectory: true)
            .appendingPathComponent("xdiary-data.json", isDirectory: false)
    }

    var selectedEntry: DiaryEntry? {
        data.entries.first { $0.date == selectedDate }
    }

    var activeBlocks: [TemplateBlock] {
        if let selectedEntry { return selectedEntry.template.blocks }
        return activeTemplate?.blocks ?? []
    }

    var activeTemplateName: String {
        selectedEntry?.template.name ?? activeTemplate?.name ?? "未选择模板"
    }

    var activeTemplate: DiaryTemplate? {
        let desiredID = selectedTemplateID ?? data.defaultTemplateID
        return data.templates.first { $0.id == desiredID } ?? data.templates.first
    }

    var hasUnsavedChanges: Bool {
        if case .failed = saveState { return true }
        return false
    }

    func entry(on date: String) -> DiaryEntry? {
        data.entries.first { $0.date == date }
    }

    func entries(inMonth month: String) -> [DiaryEntry] {
        data.entries
            .filter { $0.date.hasPrefix(month + "-") }
            .sorted { $0.date > $1.date }
    }

    func availableMonths() -> [String] {
        Set(data.entries.map { String($0.date.prefix(7)) }).sorted(by: >)
    }

    func selectDate(_ date: String) {
        guard (try? calendar.validate(date)) != nil else { return }
        selectedDate = date
        selectedTemplateID = data.defaultTemplateID
        page = .diary
    }

    func moveSelection(byDays days: Int) {
        guard let next = try? calendar.addingDays(days, to: selectedDate) else { return }
        selectDate(next)
    }

    func chooseTemplate(_ id: UUID) {
        guard data.templates.contains(where: { $0.id == id }) else { return }
        selectedTemplateID = id
    }

    func setAnswer(_ value: DiaryAnswerValue, for blockID: UUID) throws {
        try updateAnswerInMemory(value, for: blockID)
        try persistCurrentData()
    }

    func setAnswerDeferred(_ value: DiaryAnswerValue, for blockID: UUID) throws {
        try updateAnswerInMemory(value, for: blockID)
        scheduleAnswerSave()
    }

    func flushPendingSave() throws {
        guard pendingAnswerSave != nil else { return }
        pendingAnswerSave?.cancel()
        pendingAnswerSave = nil
        try persistCurrentData()
    }

    private func updateAnswerInMemory(_ value: DiaryAnswerValue, for blockID: UUID) throws {
        var candidate = data
        var index: Int
        if let existingIndex = candidate.entries.firstIndex(where: { $0.date == selectedDate }) {
            index = existingIndex
        } else {
            guard let templateID = (selectedTemplateID ?? candidate.defaultTemplateID ?? candidate.templates.first?.id) else {
                throw XDiaryError.invalidBackup("请先创建一个日记模板")
            }
            let entry = try candidate.createEntry(on: selectedDate, templateID: templateID, now: now())
            index = candidate.entries.firstIndex(where: { $0.id == entry.id })!
        }
        candidate.entries[index].answers[blockID] = value
        candidate.entries[index].updatedAt = now()
        data = candidate
    }

    func replaceSelectedEntryTemplate(with templateID: UUID) throws {
        var candidate = data
        candidate.entries.removeAll { $0.date == selectedDate }
        _ = try candidate.createEntry(on: selectedDate, templateID: templateID, now: now())
        data = candidate
        selectedTemplateID = templateID
        try persistCurrentData()
    }

    func deleteSelectedEntry() throws {
        data.entries.removeAll { $0.date == selectedDate }
        try persistCurrentData()
    }

    func saveTemplate(_ template: DiaryTemplate) throws {
        guard template.blocks.contains(where: \.isInput) else {
            throw XDiaryError.invalidTemplate(template.id, reason: "请至少添加一个输入项")
        }
        var candidate = data
        var normalized = template
        normalized.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.updatedAt = now()
        if let index = candidate.templates.firstIndex(where: { $0.id == template.id }) {
            candidate.templates[index] = normalized
        } else {
            candidate.templates.append(normalized)
        }
        if candidate.defaultTemplateID == nil { candidate.defaultTemplateID = normalized.id }
        try candidate.validate()
        data = candidate
        try persistCurrentData()
    }

    func duplicateTemplate(_ template: DiaryTemplate) throws -> DiaryTemplate {
        let time = now()
        let duplicate = DiaryTemplate(
            name: "\(template.name)（副本）",
            blocks: template.blocks.map { $0.copyWithNewID() },
            createdAt: time,
            updatedAt: time
        )
        try saveTemplate(duplicate)
        return duplicate
    }

    func deleteTemplate(_ id: UUID) throws {
        data.templates.removeAll { $0.id == id }
        if data.defaultTemplateID == id { data.defaultTemplateID = data.templates.first?.id }
        try persistCurrentData()
    }

    func setDefaultTemplate(_ id: UUID) throws {
        guard data.templates.contains(where: { $0.id == id }) else {
            throw XDiaryError.templateNotFound(id)
        }
        data.defaultTemplateID = id
        selectedTemplateID = id
        try persistCurrentData()
    }

    func importData(_ incoming: DiaryData, strategy: ImportConflictStrategy) throws {
        let candidate = try DiaryImporter.merge(local: data, incoming: incoming, strategy: strategy)
        saveState = .saving
        do {
            try fileStore.save(candidate, to: dataURL)
            data = candidate
            selectedTemplateID = data.defaultTemplateID
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    func importPreview(for incoming: DiaryData) -> ImportPreview {
        let entryConflicts = incoming.entries.filter { remote in
            data.entries.contains { local in DiaryImporter.entriesConflict(local, remote) }
        }.count
        let affectedLocalEntries = data.entries.filter { local in
            incoming.entries.contains { remote in DiaryImporter.entriesConflict(local, remote) }
        }.count
        return ImportPreview(
            newEntries: incoming.entries.count - entryConflicts,
            entryConflicts: entryConflicts,
            affectedLocalEntries: affectedLocalEntries,
            newTemplates: incoming.templates.filter { remote in !data.templates.contains { $0.id == remote.id } }.count,
            templateConflicts: incoming.templates.filter { remote in data.templates.contains { $0.id == remote.id } }.count
        )
    }

    func retrySave() throws {
        try persistCurrentData()
    }

    func backupData() throws -> Data {
        try DiaryBackup.encode(data)
    }

    func markdown(from start: String? = nil, through end: String? = nil) throws -> String {
        try DiaryMarkdownExporter.export(data, from: start, through: end)
    }

    private func persistCurrentData() throws {
        pendingAnswerSave?.cancel()
        pendingAnswerSave = nil
        saveState = .saving
        do {
            try fileStore.save(data, to: dataURL)
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    private func scheduleAnswerSave() {
        pendingAnswerSave?.cancel()
        saveState = .saving
        pendingAnswerSave = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, let self else { return }
                self.pendingAnswerSave = nil
                try self.persistCurrentData()
            } catch is CancellationError {
                // A newer edit or an explicit flush replaced this pending save.
            } catch {
                // persistCurrentData already exposes the failure through saveState.
            }
        }
    }
}

struct ImportPreview: Equatable {
    let newEntries: Int
    let entryConflicts: Int
    let affectedLocalEntries: Int
    let newTemplates: Int
    let templateConflicts: Int
}

extension TemplateBlock {
    func copyWithNewID() -> TemplateBlock {
        switch self {
        case let .heading(_, level, title):
            .heading(level: level, title: title)
        case let .text(_, prompt, placeholder):
            .text(prompt: prompt, placeholder: placeholder)
        case let .textArea(_, prompt, placeholder):
            .textArea(prompt: prompt, placeholder: placeholder)
        case let .number(_, prompt, unit, min, max, step):
            .number(prompt: prompt, unit: unit, min: min, max: max, step: step)
        case let .rating(_, prompt, unit, min, max, step):
            .rating(prompt: prompt, unit: unit, min: min, max: max, step: step)
        }
    }
}
