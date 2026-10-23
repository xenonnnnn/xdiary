import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var store: AppStore
    @State private var showsTransfer = false
    @State private var showsHelp = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                store: store,
                openTransfer: { showsTransfer = true },
                openHelp: { showsHelp = true }
            )
            .frame(width: 238)
            Divider().overlay(XDiaryStyle.line)
            VStack(spacing: 0) {
                TopBar(store: store, openTransfer: { showsTransfer = true })
                Divider().overlay(XDiaryStyle.line)
                if case let .failed(message) = store.saveState {
                    SaveFailureBar(store: store, message: message)
                }
                ZStack {
                    DiaryDetailView(store: store)
                        .id(store.selectedDate)
                        .opacity(store.page == .diary ? 1 : 0)
                        .allowsHitTesting(store.page == .diary)
                        .accessibilityHidden(store.page != .diary)
                    TemplateManagerView(store: store)
                        .opacity(store.page == .templates ? 1 : 0)
                        .allowsHitTesting(store.page == .templates)
                        .accessibilityHidden(store.page != .templates)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(XDiaryStyle.paper)
            }
        }
        .background(XDiaryStyle.paper)
        .sheet(isPresented: $showsTransfer) { TransferView(store: store) }
        .sheet(isPresented: $showsHelp) { HelpView() }
        .onDisappear { try? store.flushPendingSave() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            try? store.flushPendingSave()
        }
    }
}

private struct TopBar: View {
    @ObservedObject var store: AppStore
    let openTransfer: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Text(store.page == .diary ? "我的日记" : "我的模板")
                .foregroundStyle(XDiaryStyle.muted)
            Image(systemName: "chevron.right").font(.system(size: 10))
                .foregroundStyle(XDiaryStyle.muted.opacity(0.7))
            Text(store.page == .diary ? chineseMonth(store.selectedDate) : "模板管理")
            Spacer()
            saveStatus
            Divider().frame(height: 15)
            Button(action: openTransfer) {
                Label("导入与导出", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(XDiaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .frame(height: 54)
        .background(Color.white)
    }

    @ViewBuilder private var saveStatus: some View {
        switch store.saveState {
        case .idle:
            Text("填写后自动保存").foregroundStyle(XDiaryStyle.muted)
        case .saving:
            Label("正在保存…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(XDiaryStyle.muted)
        case .saved:
            Label("已保存在本机", systemImage: "checkmark")
                .foregroundStyle(XDiaryStyle.accent)
        case .failed:
            Label("保存失败", systemImage: "exclamationmark.triangle")
                .foregroundStyle(XDiaryStyle.danger)
        }
    }
}

private struct SaveFailureBar: View {
    @ObservedObject var store: AppStore
    let message: String
    @State private var recoveryMessage: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
            Text("内容仍在当前窗口，但尚未写入磁盘：\(message)")
                .lineLimit(2)
            Spacer()
            Button("重试保存") {
                do { try store.retrySave() } catch { recoveryMessage = error.localizedDescription }
            }
            .buttonStyle(XDiaryButtonStyle())
            Button("应急导出") {
                do { _ = try NativeFilePanels.save(data: store.backupData(), suggestedName: "xdiary-recovery.json", contentType: .json) }
                catch { recoveryMessage = error.localizedDescription }
            }
            .buttonStyle(XDiaryButtonStyle(primary: true))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 42)
        .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.18))
        .background(Color(red: 1.0, green: 0.97, blue: 0.90))
        .help(recoveryMessage ?? "")
    }
}

private struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "book.pages").foregroundStyle(XDiaryStyle.accent)
                Text("xdiary · 写给自己").fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(XDiaryIconButtonStyle())
            }
            Text("选择日期，跟着模板写下今天。每次输入都会原子保存到这台 Mac。")
            Text("模板修改只影响以后新建的日记，历史日记保留填写时的结构。")
            Text("完整 JSON 备份用于迁移到其他 Mac；Markdown 按日期和问题组织，适合每周交给 AI 分析。")
            Text("请定期导出完整备份。应用不会联网或自动上传日记。")
                .foregroundStyle(XDiaryStyle.muted)
                .padding(12)
                .background(XDiaryStyle.soft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .font(XDiaryStyle.font)
        .padding(22)
        .frame(width: 480)
    }
}

func chineseMonth(_ date: String) -> String {
    guard date.count >= 7 else { return date }
    return "\(date.prefix(4)) 年 \(Int(date.dropFirst(5).prefix(2)) ?? 0) 月"
}
