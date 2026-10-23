import AppKit
import SwiftUI
import UniformTypeIdentifiers
import XDiaryCore

@MainActor
enum NativeFilePanels {
    static func save(data: Data, suggestedName: String, contentType: UTType) throws -> Bool {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK else { return false }
        return try write(data, to: panel.url)
    }

    static func write(_ data: Data, to url: URL?) throws -> Bool {
        guard let url else { return false }
        try data.write(to: url, options: .atomic)
        return true
    }

    static func openJSON(maxBytes: Int = 20 * 1024 * 1024) throws -> Data? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择由 xdiary 导出的完整 JSON 备份"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxBytes {
            throw XDiaryError.invalidBackup("文件超过 20 MB")
        }
        let encoded = try Data(contentsOf: url, options: .mappedIfSafe)
        guard encoded.count <= maxBytes else {
            throw XDiaryError.invalidBackup("文件超过 20 MB")
        }
        return encoded
    }
}

struct TransferView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var fromDate = ""
    @State private var throughDate = ""
    @State private var incoming: DiaryData?
    @State private var strategy: ImportConflictStrategy = .keepLocal
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("导入与导出").fontWeight(.semibold)
                    Text("你的日记，由你保管。").foregroundStyle(XDiaryStyle.muted)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(XDiaryIconButtonStyle())
            }
            .padding(22)
            Picker("数据操作", selection: $tab) {
                Text("导出日记").tag(0)
                Text("导入备份").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
            Divider().overlay(XDiaryStyle.line)
            ScrollView {
                if tab == 0 { exportContent } else { importContent }
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .foregroundStyle(XDiaryStyle.danger)
                    .padding(.horizontal, 22).padding(.bottom, 14)
            } else if let message {
                Label(message, systemImage: "checkmark")
                    .foregroundStyle(XDiaryStyle.accent)
                    .padding(.horizontal, 22).padding(.bottom, 14)
            }
        }
        .font(XDiaryStyle.font)
        .frame(width: 620, height: 590)
        .onAppear { if fromDate.isEmpty { setThisWeek() } }
        .onChange(of: tab) { _, _ in message = nil; errorMessage = nil }
    }

    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            transferSection(icon: "doc.plaintext", title: "一份清晰的复盘", subtitle: "Markdown 按日期保留标题、问题和原始回答，适合阅读或交给 AI 分析。") {
                HStack(spacing: 7) {
                    quickButton("本周", action: setThisWeek)
                    quickButton("上周", action: setLastWeek)
                    quickButton("本月", action: setThisMonth)
                    quickButton("全部", action: setAllDates)
                }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("开始日期").foregroundStyle(XDiaryStyle.muted)
                        DatePicker("开始日期", selection: dateBinding($fromDate), displayedComponents: .date).labelsHidden()
                    }
                    Text("至").foregroundStyle(XDiaryStyle.muted).padding(.top, 20)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("结束日期").foregroundStyle(XDiaryStyle.muted)
                        DatePicker("结束日期", selection: dateBinding($throughDate), displayedComponents: .date).labelsHidden()
                    }
                    Spacer()
                }
                HStack {
                    Text("已选择 \(selectedEntryCount) 篇日记").foregroundStyle(XDiaryStyle.muted)
                    Spacer()
                    Button {
                        do {
                            let text = try store.markdown(from: fromDate, through: throughDate)
                            let didSave = try NativeFilePanels.save(
                                data: Data(text.utf8),
                                suggestedName: "xdiary-\(fromDate)_\(throughDate).md",
                                contentType: UTType(filenameExtension: "md") ?? .plainText
                            )
                            message = didSave ? "Markdown 已导出，可直接交给 AI 阅读。" : nil
                            errorMessage = nil
                        } catch { errorMessage = error.localizedDescription }
                    } label: { Label("导出 Markdown", systemImage: "square.and.arrow.down") }
                    .buttonStyle(XDiaryButtonStyle(primary: true))
                    .disabled(fromDate > throughDate || selectedEntryCount == 0)
                }
            }

            Divider().overlay(XDiaryStyle.line).padding(.horizontal, 22)

            transferSection(icon: "archivebox", title: "完整备份，安心迁移", subtitle: "JSON 包含全部日记、模板和默认设置，可导入另一台 Mac 的 xdiary。") {
                HStack {
                    Text("\(store.data.entries.count) 篇日记 · \(store.data.templates.count) 个模板")
                        .foregroundStyle(XDiaryStyle.muted)
                    Spacer()
                    Button {
                        do {
                            let didSave = try NativeFilePanels.save(
                                data: store.backupData(),
                                suggestedName: "xdiary-backup-\(store.calendar.dateString(for: Date())).json",
                                contentType: .json
                            )
                            message = didSave ? "完整备份已导出。" : nil
                            errorMessage = nil
                        } catch { errorMessage = error.localizedDescription }
                    } label: { Label("下载完整备份", systemImage: "square.and.arrow.down") }
                    .buttonStyle(XDiaryButtonStyle())
                }
            }
            Label("导出文件包含日记原文，请保存在你信任的位置。", systemImage: "lock.shield")
                .foregroundStyle(XDiaryStyle.muted)
                .padding(.horizontal, 22).padding(.bottom, 20)
        }
    }

    private var importContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc").font(.system(size: 25, weight: .light)).foregroundStyle(XDiaryStyle.accent)
                Text("选择 xdiary 完整备份").fontWeight(.medium)
                Text("支持 .json，最大 20 MB").foregroundStyle(XDiaryStyle.muted)
                Button("选择备份文件…") { chooseBackup() }
                    .buttonStyle(XDiaryButtonStyle(primary: true))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28)
            .background(XDiaryStyle.soft)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(XDiaryStyle.line, style: StrokeStyle(lineWidth: 1, dash: [5])))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            if let incoming {
                let preview = store.importPreview(for: incoming)
                VStack(alignment: .leading, spacing: 11) {
                    Label("备份已检查，可以导入", systemImage: "checkmark.shield")
                        .fontWeight(.medium).foregroundStyle(XDiaryStyle.accent)
                    Text("新增 \(preview.newEntries) 篇日记 · 新增 \(preview.newTemplates) 个模板")
                    Text("\(preview.entryConflicts) 条导入日记存在冲突 · \(preview.templateConflicts) 个模板存在冲突")
                        .foregroundStyle(XDiaryStyle.muted)
                    if preview.affectedLocalEntries > 0 {
                        Text("选择使用备份版本时，将替换 \(preview.affectedLocalEntries) 篇本机日记。")
                            .foregroundStyle(XDiaryStyle.muted)
                    }
                    Picker("冲突处理", selection: $strategy) {
                        Text("保留本机版本，只添加新内容").tag(ImportConflictStrategy.keepLocal)
                        Text("使用备份版本，替换冲突内容").tag(ImportConflictStrategy.useImport)
                    }
                    .pickerStyle(.radioGroup)
                    HStack {
                        Spacer()
                        Button("确认导入") {
                            do {
                                try store.importData(incoming, strategy: strategy)
                                message = "导入完成，日记与模板已保存在本机。"
                                errorMessage = nil
                                self.incoming = nil
                            } catch { errorMessage = error.localizedDescription }
                        }
                        .buttonStyle(XDiaryButtonStyle(primary: true))
                    }
                }
                .padding(16)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(XDiaryStyle.line))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("Markdown 用于阅读；恢复日记请使用完整 JSON 备份。")
                .foregroundStyle(XDiaryStyle.muted)
        }
        .padding(22)
    }

    private func transferSection<Content: View>(icon: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).foregroundStyle(XDiaryStyle.accent)
                .frame(width: 34, height: 34).background(XDiaryStyle.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 12) {
                Text(title).fontWeight(.medium)
                Text(subtitle).foregroundStyle(XDiaryStyle.muted).fixedSize(horizontal: false, vertical: true)
                content()
            }
        }
        .padding(22)
    }

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(XDiaryButtonStyle())
    }

    private var selectedEntryCount: Int {
        store.data.entries.filter { $0.date >= fromDate && $0.date <= throughDate }.count
    }

    private func dateBinding(_ string: Binding<String>) -> Binding<Date> {
        Binding(
            get: { (try? store.calendar.date(from: string.wrappedValue)) ?? Date() },
            set: { string.wrappedValue = store.calendar.dateString(for: $0) }
        )
    }

    private func setThisWeek() {
        let today = store.calendar.dateString(for: Date())
        guard let date = try? store.calendar.date(from: today) else { return }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .autoupdatingCurrent
        let offset = -((calendar.component(.weekday, from: date) + 5) % 7)
        fromDate = (try? store.calendar.addingDays(offset, to: today)) ?? today
        throughDate = (try? store.calendar.addingDays(6, to: fromDate)) ?? today
    }

    private func setLastWeek() {
        setThisWeek()
        fromDate = (try? store.calendar.addingDays(-7, to: fromDate)) ?? fromDate
        throughDate = (try? store.calendar.addingDays(6, to: fromDate)) ?? throughDate
    }

    private func setThisMonth() {
        let today = store.calendar.dateString(for: Date())
        if let dates = try? store.calendar.dates(inMonthContaining: today) {
            fromDate = dates.first ?? today; throughDate = dates.last ?? today
        }
    }

    private func setAllDates() {
        let dates = store.data.entries.map(\.date).sorted()
        let today = store.calendar.dateString(for: Date())
        fromDate = dates.first ?? today; throughDate = dates.last ?? today
    }

    private func chooseBackup() {
        do {
            guard let encoded = try NativeFilePanels.openJSON() else { return }
            incoming = try DiaryBackup.decode(encoded)
            message = nil; errorMessage = nil
        } catch {
            incoming = nil; message = nil; errorMessage = error.localizedDescription
        }
    }
}
