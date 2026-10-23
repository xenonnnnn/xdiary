import SwiftUI
import XDiaryCore

struct TemplateManagerView: View {
    @ObservedObject var store: AppStore
    @State private var draft: DiaryTemplate?
    @State private var original: DiaryTemplate?
    @State private var errorMessage: String?
    @State private var deleteCandidate: DiaryTemplate?
    @State private var confirmsDiscard = false

    init(store: AppStore) {
        self.store = store
        let recovery = try? TemplateDraftRecoveryStore.restore(for: store.dataURL)
        _draft = State(initialValue: recovery?.draft)
        _original = State(initialValue: recovery?.original)
    }

    var body: some View {
        Group {
            if let draft {
                editor(draft)
            } else {
                templateList
            }
        }
        .alert("删除这个模板？", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let id = deleteCandidate?.id { try? store.deleteTemplate(id) }
                deleteCandidate = nil
            }
            Button("取消", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("已经使用此模板写下的历史日记会完整保留。")
        }
        .confirmationDialog("放弃未保存的模板修改？", isPresented: $confirmsDiscard) {
            Button("放弃修改", role: .destructive) { draft = nil; original = nil; errorMessage = nil }
            Button("继续编辑", role: .cancel) {}
        }
        .onChange(of: draft) { _, _ in syncDraftRecovery() }
        .onChange(of: original) { _, _ in syncDraftRecovery() }
    }

    private var templateList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("模板").fontWeight(.semibold)
                    Text("让每天的记录，有一点自己的秩序。").foregroundStyle(XDiaryStyle.muted)
                }
                Spacer()
                Button { createTemplate() } label: { Label("创建模板", systemImage: "plus") }
                    .buttonStyle(XDiaryButtonStyle(primary: true))
            }
            .padding(.horizontal, 36).frame(height: 110)
            Divider().overlay(XDiaryStyle.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("我的模板").fontWeight(.medium)
                        Spacer()
                        Text("\(store.data.templates.count) 个模板").foregroundStyle(XDiaryStyle.muted)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], spacing: 18) {
                        ForEach(store.data.templates) { template in templateCard(template) }
                    }
                    Label("模板修改只会用于之后新建的日记，历史日记保留原来的内容和结构。", systemImage: "checkmark")
                        .foregroundStyle(XDiaryStyle.muted)
                        .padding(.top, 6)
                }
                .padding(36)
            }
        }
    }

    private func templateCard(_ template: DiaryTemplate) -> some View {
        let isDefault = template.id == store.data.defaultTemplateID
        return VStack(alignment: .leading, spacing: 13) {
            Button { open(template) } label: {
                HStack {
                    Image(systemName: "doc.text").foregroundStyle(XDiaryStyle.muted)
                    Text(template.name).fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(XDiaryStyle.muted)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(XDiaryButtonStyle(quiet: true))
            HStack(spacing: 9) {
                Text("\(template.blocks.filter(\.isInput).count) 个输入项").foregroundStyle(XDiaryStyle.muted)
                if isDefault {
                    Label("默认模板", systemImage: "checkmark")
                        .foregroundStyle(XDiaryStyle.accent)
                        .padding(.horizontal, 6).frame(height: 22)
                        .background(XDiaryStyle.accentSoft).clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(template.blocks.filter(\.isInput).prefix(3))) { block in
                    Text(block.displayText).foregroundStyle(XDiaryStyle.muted).lineLimit(1)
                }
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) { Rectangle().fill(XDiaryStyle.line).frame(width: 1) }
            Spacer(minLength: 4)
            Divider().overlay(XDiaryStyle.line)
            HStack {
                Button {
                    try? store.setDefaultTemplate(template.id)
                } label: {
                    Label(isDefault ? "默认使用" : "设为默认", systemImage: "star")
                }
                .buttonStyle(XDiaryButtonStyle(quiet: true)).disabled(isDefault)
                Spacer()
                Button {
                    if let duplicate = try? store.duplicateTemplate(template) { open(duplicate) }
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(XDiaryIconButtonStyle()).help("复制模板")
                Button { deleteCandidate = template } label: { Image(systemName: "trash") }
                    .buttonStyle(XDiaryIconButtonStyle()).help("删除模板")
            }
        }
        .padding(15)
        .frame(minHeight: 245, alignment: .top)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isDefault ? XDiaryStyle.accent.opacity(0.35) : XDiaryStyle.line))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func editor(_ current: DiaryTemplate) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { requestCloseEditor() } label: { Label("模板", systemImage: "arrow.left") }
                    .buttonStyle(XDiaryButtonStyle(quiet: true))
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(XDiaryStyle.muted)
                Text(store.data.templates.contains { $0.id == current.id } ? "编辑模板" : "创建模板")
                    .foregroundStyle(XDiaryStyle.muted)
                Spacer()
                if current != original { Text("有未保存的修改").foregroundStyle(XDiaryStyle.muted) }
                Button { saveDraft() } label: { Label("保存模板", systemImage: "checkmark") }
                    .buttonStyle(XDiaryButtonStyle(primary: true))
            }
            .padding(.horizontal, 24).frame(height: 54)
            Divider().overlay(XDiaryStyle.line)
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 19) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("模板名称").foregroundStyle(XDiaryStyle.muted)
                            TextField("模板名称", text: draftNameBinding)
                                .xdiaryField()
                        }
                        HStack {
                            Text("模板内容").fontWeight(.medium)
                            Spacer()
                            Text("\(current.blocks.count) 个内容块").foregroundStyle(XDiaryStyle.muted)
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.circle")
                                .foregroundStyle(XDiaryStyle.danger)
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        ForEach(Array(current.blocks.enumerated()), id: \.element.id) { index, block in
                            blockEditor(block, at: index)
                        }
                        addBlockMenu
                        Text("保存后可用于新日记，历史日记保持原样。")
                            .foregroundStyle(XDiaryStyle.muted)
                    }
                    .padding(24)
                }
                .frame(minWidth: 410)
                templatePreview(current)
                    .frame(minWidth: 280, idealWidth: 330, maxWidth: 380)
            }
        }
    }

    private func blockEditor(_ block: TemplateBlock, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: "%02d", index + 1)).foregroundStyle(XDiaryStyle.muted)
                Label(block.kind.chineseName, systemImage: block.kind.iconName)
                Spacer()
                Button { move(index, by: -1) } label: { Image(systemName: "arrow.up") }
                    .buttonStyle(XDiaryIconButtonStyle()).disabled(index == 0)
                Button { move(index, by: 1) } label: { Image(systemName: "arrow.down") }
                    .buttonStyle(XDiaryIconButtonStyle()).disabled(index == (draft?.blocks.count ?? 1) - 1)
                Button { draft?.blocks.remove(at: index) } label: { Image(systemName: "trash") }
                    .buttonStyle(XDiaryIconButtonStyle())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(block.kind == .heading ? "标题文字" : "问题名称").foregroundStyle(XDiaryStyle.muted)
                TextField("请输入", text: Binding(
                    get: { block.displayText },
                    set: { draft?.blocks[index] = block.withDisplayText($0) }
                )).xdiaryField()
            }
            switch block {
            case let .heading(_, level, _):
                Picker("标题层级", selection: Binding(
                    get: { level }, set: { draft?.blocks[index] = block.withHeadingLevel($0) }
                )) {
                    Text("一级标题").tag(1); Text("二级标题").tag(2); Text("三级标题").tag(3)
                }
                .pickerStyle(.segmented).frame(maxWidth: 330)
            case let .text(_, _, placeholder), let .textArea(_, _, placeholder):
                VStack(alignment: .leading, spacing: 6) {
                    Text("输入提示（可选）").foregroundStyle(XDiaryStyle.muted)
                    TextField("填写前显示的提示文字", text: Binding(
                        get: { placeholder ?? "" }, set: { draft?.blocks[index] = block.withPlaceholder($0) }
                    )).xdiaryField()
                }
            case let .number(_, _, unit, min, max, step):
                numericOptions(block, index: index, unit: unit, min: min, max: max, step: step)
            case let .rating(_, _, unit, min, max, step):
                numericOptions(block, index: index, unit: unit, min: min, max: max, step: step)
            }
        }
        .padding(14)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(XDiaryStyle.line))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func numericOptions(_ block: TemplateBlock, index: Int, unit: String?, min: Double?, max: Double?, step: Double?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            numericTextField("最小值", value: min) { draft?.blocks[index] = block.withNumeric(min: $0, max: max, step: step, unit: unit) }
            numericTextField("最大值", value: max) { draft?.blocks[index] = block.withNumeric(min: min, max: $0, step: step, unit: unit) }
            numericTextField("步长", value: step) { draft?.blocks[index] = block.withNumeric(min: min, max: max, step: $0, unit: unit) }
            VStack(alignment: .leading, spacing: 6) {
                Text("单位").foregroundStyle(XDiaryStyle.muted)
                TextField("可选", text: Binding(
                    get: { unit ?? "" },
                    set: { draft?.blocks[index] = block.withNumeric(min: min, max: max, step: step, unit: $0.isEmpty ? nil : $0) }
                )).xdiaryField()
            }
        }
    }

    private func numericTextField(_ label: String, value: Double?, changed: @escaping (Double?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).foregroundStyle(XDiaryStyle.muted)
            TextField("—", text: Binding(
                get: { value.map(formatNumber) ?? "" },
                set: { changed($0.isEmpty ? nil : Double($0)) }
            )).xdiaryField()
        }
    }

    private var addBlockMenu: some View {
        Menu {
            ForEach(TemplateBlock.Kind.allCases, id: \.self) { kind in
                Button { draft?.blocks.append(kind.newBlock()) } label: {
                    Label(kind.chineseName, systemImage: kind.iconName)
                }
            }
        } label: {
            Label("添加内容块", systemImage: "plus")
                .frame(maxWidth: .infinity).frame(height: 28)
        }
        .menuStyle(.borderlessButton)
        .background(XDiaryStyle.soft)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func templatePreview(_ template: DiaryTemplate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("实时预览", systemImage: "doc.text")
                Spacer()
                Text("内容不会保存").foregroundStyle(XDiaryStyle.muted)
            }
            .padding(.horizontal, 18).frame(height: 48)
            Divider().overlay(XDiaryStyle.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今天 · \(template.name)").fontWeight(.semibold).padding(.bottom, 4)
                    ForEach(template.blocks) { block in
                        switch block {
                        case let .heading(_, level, title):
                            Text(title).fontWeight(level == 1 ? .semibold : .medium)
                                .foregroundStyle(level == 3 ? XDiaryStyle.muted : Color.primary)
                                .padding(.leading, level > 1 ? CGFloat(level - 1) * 20 : 0)
                                .padding(.top, level == 1 ? 10 : 5)
                        case let .text(_, prompt, placeholder), let .textArea(_, prompt, placeholder):
                            VStack(alignment: .leading, spacing: 5) {
                                Text(prompt)
                                Text(placeholder ?? "在这里填写…").foregroundStyle(XDiaryStyle.muted.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                                    .background(XDiaryStyle.paper)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(XDiaryStyle.inputLine, lineWidth: 1))
                            }
                        case let .number(_, prompt, unit, _, _, _), let .rating(_, prompt, unit, _, _, _):
                            HStack { Text(prompt); Spacer(); Text("— \(unit ?? "")").foregroundStyle(XDiaryStyle.muted) }
                        }
                    }
                }
                .padding(18)
            }
        }
        .background(XDiaryStyle.sidebar)
    }

    private var draftNameBinding: Binding<String> {
        Binding(get: { draft?.name ?? "" }, set: { draft?.name = $0 })
    }

    private func createTemplate() {
        let now = Date()
        let template = DiaryTemplate(name: "新模板", blocks: [
            .heading(level: 1, title: "今天"),
            .textArea(prompt: "今天发生了什么？", placeholder: "记录值得记住的事")
        ], createdAt: now, updatedAt: now)
        original = template; draft = template; errorMessage = nil
    }

    private func open(_ template: DiaryTemplate) {
        original = template; draft = template; errorMessage = nil
    }

    private func requestCloseEditor() {
        if draft != original { confirmsDiscard = true }
        else { draft = nil; original = nil }
    }

    private func saveDraft() {
        guard let draft else { return }
        do {
            try store.saveTemplate(draft)
            self.draft = store.data.templates.first { $0.id == draft.id }
            original = self.draft
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard var blocks = draft?.blocks, blocks.indices.contains(index), blocks.indices.contains(target) else { return }
        blocks.swapAt(index, target); draft?.blocks = blocks
    }

    private func syncDraftRecovery() {
        do {
            try TemplateDraftRecoveryStore.sync(
                draft: draft,
                original: original,
                dataURL: store.dataURL
            )
        } catch {
            errorMessage = "未保存的模板草稿无法写入磁盘：\(error.localizedDescription)"
        }
    }
}

extension TemplateBlock.Kind {
    var chineseName: String {
        switch self { case .heading: "标题"; case .text: "短文本"; case .textArea: "长文本"; case .number: "数字"; case .rating: "评分" }
    }
    var iconName: String {
        switch self { case .heading: "textformat.size"; case .text: "text.cursor"; case .textArea: "text.alignleft"; case .number: "number"; case .rating: "slider.horizontal.3" }
    }
    func newBlock() -> TemplateBlock {
        switch self {
        case .heading: .heading(level: 1, title: "新的章节")
        case .text: .text(prompt: "新的问题", placeholder: nil)
        case .textArea: .textArea(prompt: "新的问题", placeholder: nil)
        case .number: .number(prompt: "记录一个数字", unit: nil, min: nil, max: nil, step: nil)
        case .rating: .rating(prompt: "今天的评分", unit: "/10", min: 0, max: 10, step: 1)
        }
    }
}

extension TemplateBlock {
    func withDisplayText(_ text: String) -> TemplateBlock {
        switch self {
        case let .heading(id, level, _): .heading(id: id, level: level, title: text)
        case let .text(id, _, placeholder): .text(id: id, prompt: text, placeholder: placeholder)
        case let .textArea(id, _, placeholder): .textArea(id: id, prompt: text, placeholder: placeholder)
        case let .number(id, _, unit, min, max, step): .number(id: id, prompt: text, unit: unit, min: min, max: max, step: step)
        case let .rating(id, _, unit, min, max, step): .rating(id: id, prompt: text, unit: unit, min: min, max: max, step: step)
        }
    }
    func withHeadingLevel(_ level: Int) -> TemplateBlock {
        guard case let .heading(id, _, title) = self else { return self }
        return .heading(id: id, level: level, title: title)
    }
    func withPlaceholder(_ placeholder: String) -> TemplateBlock {
        switch self {
        case let .text(id, prompt, _): .text(id: id, prompt: prompt, placeholder: placeholder)
        case let .textArea(id, prompt, _): .textArea(id: id, prompt: prompt, placeholder: placeholder)
        default: self
        }
    }
    func withNumeric(min: Double?, max: Double?, step: Double?, unit: String?) -> TemplateBlock {
        switch self {
        case let .number(id, prompt, _, _, _, _): .number(id: id, prompt: prompt, unit: unit, min: min, max: max, step: step)
        case let .rating(id, prompt, _, oldMin, oldMax, oldStep):
            .rating(id: id, prompt: prompt, unit: unit, min: min ?? oldMin, max: max ?? oldMax, step: step ?? oldStep)
        default: self
        }
    }
}
