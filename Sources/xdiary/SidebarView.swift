import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: AppStore
    let openTransfer: () -> Void
    let openHelp: () -> Void
    @State private var expandedMonths: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 16))
                    .foregroundStyle(XDiaryStyle.accent)
                    .frame(width: 29, height: 29)
                    .background(XDiaryStyle.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text("xdiary").fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 25)

            Button {
                store.selectDate(store.calendar.dateString(for: Date()))
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("写今天的日记")
                    Spacer()
                    Text("今天").foregroundStyle(XDiaryStyle.muted)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(XDiaryButtonStyle())
            .padding(.horizontal, 14)

            HStack {
                Text("我的日记").foregroundStyle(XDiaryStyle.muted)
                Spacer()
                Text("\(store.data.entries.count) 篇").foregroundStyle(XDiaryStyle.muted)
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, 9)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(yearGroups, id: \.year) { group in
                        Text(group.year)
                            .foregroundStyle(XDiaryStyle.muted)
                            .padding(.horizontal, 18)
                            .padding(.top, 9)
                            .padding(.bottom, 5)
                        ForEach(group.months, id: \.self) { month in
                            monthSection(month)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            VStack(spacing: 3) {
                Divider().padding(.horizontal, 8).padding(.bottom, 8)
                sidebarAction("模板管理", icon: "square.grid.2x2", active: store.page == .templates) {
                    store.page = .templates
                }
                sidebarAction("导入与导出", icon: "arrow.down.doc", active: false, action: openTransfer)
                Divider().padding(.horizontal, 8).padding(.vertical, 8)
                HStack(spacing: 7) {
                    Circle().fill(XDiaryStyle.accent.opacity(0.55)).frame(width: 5, height: 5)
                    Text("只保存在这台 Mac").foregroundStyle(XDiaryStyle.muted)
                    Spacer()
                    Button(action: openHelp) { Image(systemName: "questionmark.circle") }
                        .buttonStyle(XDiaryIconButtonStyle())
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
        }
        .background(XDiaryStyle.sidebar)
    }

    private var yearGroups: [(year: String, months: [String])] {
        let grouped = Dictionary(grouping: store.availableMonths()) { String($0.prefix(4)) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted(by: >)) }
    }

    @ViewBuilder private func monthSection(_ month: String) -> some View {
        let entries = store.entries(inMonth: month)
        let expanded = expandedMonths.contains(month)
        VStack(spacing: 2) {
            Button {
                if expanded { expandedMonths.remove(month) } else { expandedMonths.insert(month) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .frame(width: 12)
                    Text("\(Int(month.suffix(2)) ?? 0) 月")
                    Spacer()
                    Text("\(entries.count)")
                        .foregroundStyle(XDiaryStyle.muted)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(XDiaryButtonStyle(quiet: true))
            .background(store.selectedDate.hasPrefix(month) && store.page == .diary ? XDiaryStyle.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if expanded {
                VStack(spacing: 2) {
                    ForEach(entries) { entry in
                        Button {
                            store.selectDate(entry.date)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text").font(.system(size: 11))
                                Text("\(Int(entry.date.suffix(2)) ?? 0) 日")
                                Spacer()
                                Text(shortWeekday(entry.date)).foregroundStyle(XDiaryStyle.muted)
                            }
                            .padding(.leading, 23)
                            .padding(.trailing, 9)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(XDiaryButtonStyle(quiet: true))
                        .background(entry.date == store.selectedDate && store.page == .diary ? XDiaryStyle.accentSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
    }

    private func sidebarAction(_ title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 16)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(XDiaryButtonStyle(quiet: true))
        .background(active ? XDiaryStyle.accentSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 5)
    }

    private func shortWeekday(_ date: String) -> String {
        guard let value = try? store.calendar.date(from: date) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: value)
    }
}
