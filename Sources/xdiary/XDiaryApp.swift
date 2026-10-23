import AppKit
import SwiftUI
import UniformTypeIdentifiers
import XDiaryCore

@main
struct XDiaryApp: App {
    @StateObject private var bootstrap = AppBootstrap()

    var body: some Scene {
        Window("xdiary", id: "main") {
            Group {
                if let store = bootstrap.store {
                    RootView(store: store)
                } else {
                    StartupFailureView(bootstrap: bootstrap)
                }
            }
            .font(XDiaryStyle.font)
            .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        .commands { XDiaryCommands(bootstrap: bootstrap) }
    }
}

@MainActor
final class AppBootstrap: ObservableObject {
    private static let maximumBackupSize = 20 * 1_024 * 1_024
    private let dataURL: URL

    @Published var store: AppStore?
    @Published var error: String?
    @Published private(set) var isRecovering = false

    init(dataURL: URL = AppStore.defaultDataURL()) {
        self.dataURL = dataURL
        do {
            store = try AppStore(dataURL: dataURL)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func retry() {
        do {
            let reloadedStore = try AppStore(dataURL: dataURL)
            store = reloadedStore
            error = nil
        } catch {
            store = nil
            self.error = error.localizedDescription
        }
    }

    func chooseAndRestoreBackup() {
        let panel = NSOpenPanel()
        panel.title = "从完整备份恢复"
        panel.message = "选择由 xdiary 导出的完整 JSON 备份。恢复成功后，它会替换本机数据。"
        panel.prompt = "恢复"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let backupURL = panel.url else { return }
        restore(from: backupURL)
    }

    func restore(from backupURL: URL) {
        isRecovering = true
        defer { isRecovering = false }

        let isAccessingSecurityScopedResource = backupURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSecurityScopedResource {
                backupURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let values = try backupURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values.isRegularFile == false {
                throw XDiaryError.invalidBackup("请选择一个 JSON 文件")
            }
            if let fileSize = values.fileSize, fileSize > Self.maximumBackupSize {
                throw XDiaryError.invalidBackup("文件超过 20 MB 限制")
            }

            let encoded = try Data(contentsOf: backupURL, options: .mappedIfSafe)
            guard encoded.count <= Self.maximumBackupSize else {
                throw XDiaryError.invalidBackup("文件超过 20 MB 限制")
            }

            let restoredData = try DiaryBackup.decode(encoded)
            try DiaryFileStore.save(restoredData, to: dataURL)

            let reloadedStore = try AppStore(dataURL: dataURL)
            store = reloadedStore
            error = nil
        } catch {
            store = nil
            self.error = "恢复失败：\(error.localizedDescription)"
        }
    }

    func revealDataFile() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: dataURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([dataURL])
            return
        }

        let directoryURL = dataURL.deletingLastPathComponent()
        if fileManager.fileExists(atPath: directoryURL.path), NSWorkspace.shared.open(directoryURL) {
            return
        }
        error = "找不到数据文件：\(dataURL.path)"
    }
}

struct StartupFailureView: View {
    @ObservedObject var bootstrap: AppBootstrap

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(XDiaryStyle.accent)
            Text("暂时无法读取本机日记").fontWeight(.semibold)
            Text(bootstrap.error ?? "未知错误")
                .foregroundStyle(XDiaryStyle.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Text("数据文件仍保留在原位置，没有被重置。")
                .foregroundStyle(XDiaryStyle.muted)
            HStack(spacing: 8) {
                Button("重新尝试") { bootstrap.retry() }
                    .buttonStyle(XDiaryButtonStyle())
                Button(bootstrap.isRecovering ? "正在恢复…" : "从完整备份恢复…") {
                    bootstrap.chooseAndRestoreBackup()
                }
                .buttonStyle(XDiaryButtonStyle(primary: true))
                .disabled(bootstrap.isRecovering)
            }
            Button("在 Finder 中显示数据文件") { bootstrap.revealDataFile() }
                .buttonStyle(XDiaryButtonStyle(quiet: true))
        }
        .padding(40)
    }
}

struct XDiaryCommands: Commands {
    @ObservedObject var bootstrap: AppBootstrap

    var body: some Commands {
        CommandMenu("日记") {
            Button("写今天的日记") {
                guard let store = bootstrap.store else { return }
                store.selectDate(store.calendar.dateString(for: Date()))
            }
            .keyboardShortcut("n", modifiers: .command)
            Divider()
            Button("前一天") { bootstrap.store?.moveSelection(byDays: -1) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("后一天") { bootstrap.store?.moveSelection(byDays: 1) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Divider()
            Button("模板管理") { bootstrap.store?.page = .templates }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button("立即保存") { try? bootstrap.store?.retrySave() }
                .keyboardShortcut("s", modifiers: .command)
        }
    }
}
