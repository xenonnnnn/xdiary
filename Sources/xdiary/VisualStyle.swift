import SwiftUI

enum XDiaryStyle {
    static let font = Font.system(size: 14)
    static let sidebar = Color(red: 0.965, green: 0.965, blue: 0.957)
    static let diaryBackground = Color(red: 0.972, green: 0.972, blue: 0.968)
    static let paper = Color(red: 0.995, green: 0.995, blue: 0.992)
    static let soft = Color(red: 0.952, green: 0.952, blue: 0.948)
    static let line = Color(red: 0.875, green: 0.875, blue: 0.865)
    static let inputLine = Color(red: 0.82, green: 0.82, blue: 0.81)
    static let muted = Color(red: 0.46, green: 0.46, blue: 0.44)
    static let accent = Color(red: 0.34, green: 0.34, blue: 0.32)
    static let accentSoft = Color(red: 0.91, green: 0.91, blue: 0.90)
    static let danger = Color(red: 0.64, green: 0.26, blue: 0.23)
}

struct XDiaryButtonStyle: ButtonStyle {
    var primary = false
    var quiet = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XDiaryStyle.font)
            .foregroundStyle(primary ? Color.white : Color.primary.opacity(0.82))
            .padding(.horizontal, quiet ? 6 : 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(primary ? XDiaryStyle.accent.opacity(configuration.isPressed ? 0.82 : 1) : (configuration.isPressed ? XDiaryStyle.soft : Color.white.opacity(quiet ? 0 : 1)))
            )
            .overlay {
                if !quiet {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(primary ? XDiaryStyle.accent : XDiaryStyle.line, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
    }
}

struct XDiaryIconButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XDiaryStyle.font)
            .frame(width: 28, height: 28)
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.72))
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? XDiaryStyle.accent : (configuration.isPressed ? XDiaryStyle.soft : Color.clear))
            )
            .contentShape(Rectangle())
    }
}

extension View {
    func xdiaryField() -> some View {
        self
            .font(XDiaryStyle.font)
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(XDiaryStyle.paper)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(XDiaryStyle.inputLine, lineWidth: 1))
    }
}
