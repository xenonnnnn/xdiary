import Foundation
import SwiftUI
import XDiaryCore

struct DiaryDetailView: View {
    @ObservedObject var store: AppStore
    @State private var showsCalendar = false
    @State private var pendingTemplate: DiaryTemplate?
    @State private var confirmsDelete = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    intro
                    weekStrip
                    templateBar
                    fields
                    HStack(spacing: 12) {
                        Rectangle().fill(XDiaryStyle.line).frame(width: 30, height: 1)
                        Text("写下来，就很好。").foregroundStyle(XDiaryStyle.muted.opacity(0.8))
                        Rectangle().fill(XDiaryStyle.line).frame(width: 30, height: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    if store.selectedEntry != nil {
                        Button("删除这篇日记") { confirmsDelete = true }
                            .buttonStyle(XDiaryButtonStyle(quiet: true))
                            .foregroundStyle(XDiaryStyle.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: 780)
                .padding(.horizontal, 42)
                .padding(.top, 38)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity)
            }
            Divider().overlay(XDiaryStyle.line)
            footer
        }
        .background(XDiaryStyle.paper)
        .confirmationDialog("更换这篇日记的模板？", isPresented: Binding(
            get: { pendingTemplate != nil },
            set: { if !$0 { pendingTemplate = nil } }
        )) {
            if let pendingTemplate {
                Button("清空内容并改用“\(pendingTemplate.name)”", role: .destructive) {
                    try? store.replaceSelectedEntryTemplate(with: pendingTemplate.id)
                    self.pendingTemplate = nil
                }
                Button("取消", role: .cancel) { self.pendingTemplate = nil }
            }
        } message: {
            Text("当前日期已填写的内容会被清空，其他日记不会改变。")
        }
        .alert("删除这篇日记？", isPresented: $confirmsDelete) {
            Button("删除", role: .destructive) { try? store.deleteSelectedEntry() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销，建议先导出完整备份。")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack(spacing: 8) {
                Rectangle().fill(XDiaryStyle.accent.opacity(0.55)).frame(width: 16, height: 1)
                Text("一天一页，慢慢了解自己").foregroundStyle(XDiaryStyle.muted)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(longDate(store.selectedDate)).fontWeight(.semibold)
                        if store.selectedDate == store.calendar.dateString(for: Date()) {
                            Text("今天")
                                .foregroundStyle(XDiaryStyle.accent)
                                .padding(.horizontal, 6)
                                .frame(height: 22)
                                .background(XDiaryStyle.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text("\(weekday(store.selectedDate)) · \(store.selectedEntry == nil ? "留一点时间，写给自己。" : "平凡的一天，也值得被记住。")")
                        .foregroundStyle(XDiaryStyle.muted)
                }
                Spacer()
                HStack(spacing: 3) {
                    Button { store.moveSelection(byDays: -1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(XDiaryIconButtonStyle()).help("前一天  ⌘⌥←")
                    Button { showsCalendar.toggle() } label: { Label("选择日期", systemImage: "calendar") }
                        .buttonStyle(XDiaryButtonStyle())
                        .popover(isPresented: $showsCalendar, arrowEdge: .bottom) {
                            DatePicker("选择日期", selection: dateBinding, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .padding(14)
                                .frame(width: 280)
                        }
                    Button { store.moveSelection(byDays: 1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(XDiaryIconButtonStyle()).help("后一天  ⌘⌥→")
                }
            }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: 6) {
                    Text(shortWeekday(date)).foregroundStyle(XDiaryStyle.muted)
                    Button("\(Int(date.suffix(2)) ?? 0)") { store.selectDate(date) }
                        .buttonStyle(XDiaryIconButtonStyle(selected: date == store.selectedDate))
                    Circle()
                        .fill(store.entry(on: date) == nil ? Color.clear : XDiaryStyle.accent.opacity(0.65))
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 12)
        .background(XDiaryStyle.soft)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(XDiaryStyle.line))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .padding(.top, 27)
    }

    private var templateBar: some View {
        HStack {
            Label(store.activeTemplateName, systemImage: "square.grid.2x2")
                .foregroundStyle(XDiaryStyle.muted)
            Spacer()
            if store.selectedDate != store.calendar.dateString(for: Date()) {
                Button("回到今天") { store.selectDate(store.calendar.dateString(for: Date())) }
                    .buttonStyle(XDiaryButtonStyle(quiet: true))
            }
            Menu {
                ForEach(store.data.templates) { template in
                    Button(template.name) {
                        if store.selectedEntry == nil {
                            store.chooseTemplate(template.id)
                        } else if store.selectedEntry?.template.sourceTemplateID != template.id {
                            pendingTemplate = template
                        }
                    }
                }
            } label: {
                Label("切换模板", systemImage: "chevron.down")
                    .frame(height: 28)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.top, 23)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(XDiaryStyle.line).frame(height: 1) }
    }

    @ViewBuilder private var fields: some View {
        if store.activeBlocks.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "square.grid.2x2").font(.system(size: 24, weight: .light))
                Text("先创建一个适合你的日记模板")
                Button("创建模板") { store.page = .templates }
                    .buttonStyle(XDiaryButtonStyle(primary: true))
            }
            .foregroundStyle(XDiaryStyle.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.activeBlocks) { block in
                    DiaryBlockView(store: store, block: block)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(XDiaryStyle.diaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(.top, 16)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(filledCount) / \(inputCount) 项已填写 · \(characterCount) 字")
            Spacer()
            Label("本地记录，安心书写", systemImage: "checkmark.shield")
        }
        .foregroundStyle(XDiaryStyle.muted)
        .padding(.horizontal, 24)
        .frame(height: 38)
        .background(Color.white)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { (try? store.calendar.date(from: store.selectedDate)) ?? Date() },
            set: { store.selectDate(store.calendar.dateString(for: $0)); showsCalendar = false }
        )
    }

    private var weekDates: [String] {
        guard let selected = try? store.calendar.date(from: store.selectedDate) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let weekday = calendar.component(.weekday, from: selected)
        let offset = -((weekday + 5) % 7)
        guard let monday = try? store.calendar.addingDays(offset, to: store.selectedDate) else { return [] }
        return (0..<7).compactMap { try? store.calendar.addingDays($0, to: monday) }
    }

    private var inputBlocks: [TemplateBlock] { store.activeBlocks.filter(\.isInput) }
    private var inputCount: Int { inputBlocks.count }
    private var filledCount: Int {
        inputBlocks.filter { block in
            guard let value = store.selectedEntry?.answers[block.id] else { return false }
            switch value {
            case let .string(text): return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .number: return true
            case .null: return false
            }
        }.count
    }
    private var characterCount: Int {
        store.selectedEntry?.answers.values.reduce(0) { count, value in
            count + (value.stringValue?.filter { !$0.isWhitespace }.count ?? 0)
        } ?? 0
    }

    private func longDate(_ date: String) -> String {
        guard date.count == 10 else { return date }
        return "\(date.prefix(4)) 年 \(Int(date.dropFirst(5).prefix(2)) ?? 0) 月 \(Int(date.suffix(2)) ?? 0) 日"
    }

    private func weekday(_ date: String) -> String {
        formatDate(date, pattern: "EEEE")
    }
    private func shortWeekday(_ date: String) -> String {
        formatDate(date, pattern: "EEE").replacingOccurrences(of: "星期", with: "周")
    }
    private func formatDate(_ date: String, pattern: String) -> String {
        guard let value = try? store.calendar.date(from: date) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = pattern
        return formatter.string(from: value)
    }
}

private struct DiaryBlockView: View {
    @ObservedObject var store: AppStore
    let block: TemplateBlock

    var body: some View {
        switch block {
        case let .heading(_, level, title):
            Text(title)
                .font(XDiaryStyle.font.weight(level == 1 ? .semibold : .medium))
                .foregroundStyle(level == 3 ? XDiaryStyle.muted : Color.primary.opacity(0.83))
                .padding(.leading, level > 1 ? CGFloat(level - 1) * 20 : 0)
                .padding(.top, level == 1 ? 25 : 17)
                .padding(.bottom, 8)
        case let .text(id, prompt, placeholder):
            fieldLabel(prompt) {
                TextField(placeholder ?? "写一点什么…", text: stringBinding(id), axis: .vertical)
                    .lineLimit(1...)
                    .xdiaryField()
            }
        case let .textArea(id, prompt, placeholder):
            fieldLabel(prompt) {
                TextField(placeholder ?? "从这里开始写下你的想法…", text: stringBinding(id), axis: .vertical)
                    .lineLimit(1...)
                    .xdiaryField()
            }
        case let .number(id, prompt, unit, min, max, step):
            fieldLabel(prompt) {
                NumericDiaryField(store: store, id: id, unit: unit, min: min, max: max, step: step, rating: false)
            }
        case let .rating(id, prompt, unit, min, max, step):
            fieldLabel(prompt) {
                NumericDiaryField(store: store, id: id, unit: unit, min: min, max: max, step: step, rating: true)
            }
        }
    }

    private func fieldLabel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(Color.primary.opacity(0.78))
            content()
        }
        .padding(.bottom, 11)
    }

    private func stringBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { store.selectedEntry?.answers[id]?.stringValue ?? "" },
            set: { try? store.setAnswerDeferred(.string($0), for: id) }
        )
    }
}

struct NumericDiaryField: View {
    @ObservedObject var store: AppStore
    let id: UUID
    let unit: String?
    let min: Double?
    let max: Double?
    let step: Double?
    let rating: Bool
    @State private var raw = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            if rating, let min, let max {
                Slider(value: sliderBinding, in: min...max, step: step ?? 1)
                    .tint(XDiaryStyle.accent)
                    .frame(maxWidth: 300)
            }
            TextField("—", text: $raw)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, value in if !value { commit() } }
                .xdiaryField()
                .frame(width: 82)
            if let unit, !unit.isEmpty { Text(unit).foregroundStyle(XDiaryStyle.muted) }
        }
        .onAppear { raw = store.selectedEntry?.answers[id]?.numberValue.map(formatNumber) ?? "" }
        .onChange(of: store.selectedEntry?.answers[id]?.numberValue) { _, value in
            guard !focused else { return }
            raw = value.map(formatNumber) ?? ""
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { store.selectedEntry?.answers[id]?.numberValue ?? min ?? 0 },
            set: {
                let value = normalizedNumber($0, min: min, max: max, step: step)
                raw = formatNumber(value)
                try? store.setAnswerDeferred(.number(value), for: id)
            }
        )
    }

    private func commit() {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try? store.setAnswer(.null, for: id)
            return
        }
        guard let value = Double(trimmed), value.isFinite else {
            raw = store.selectedEntry?.answers[id]?.numberValue.map(formatNumber) ?? ""
            return
        }
        let normalized = normalizedNumber(value, min: min, max: max, step: step)
        raw = formatNumber(normalized)
        try? store.setAnswer(.number(normalized), for: id)
    }
}

func normalizedNumber(_ value: Double, min: Double?, max: Double?, step: Double?) -> Double {
    guard let step, step > 0 else {
        return Swift.min(max ?? .infinity, Swift.max(min ?? -.infinity, value))
    }
    let base = min ?? 0
    let firstStep = min == nil ? -Double.infinity : 0
    let lastStep = max.map { floor(($0 - base) / step + 1e-9) } ?? .infinity
    let position = Swift.min(lastStep, Swift.max(firstStep, ((value - base) / step).rounded()))
    return Double(String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), base + position * step)) ?? value
}

func formatNumber(_ value: Double) -> String {
    value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.12g", value)
}
