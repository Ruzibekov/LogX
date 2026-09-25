import SwiftUI

struct ParamRowView: View {
    let key: String
    let value: String
    let isEven: Bool
    @State private var hovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(LogXType.mono(11, .semibold))
                .foregroundStyle(JSONHighlighter.spanColor(.key))
                .frame(minWidth: 90, idealWidth: 130, maxWidth: 200, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text(value.isEmpty ? "—" : value)
                .font(LogXType.mono(LogXType.meta))
                .foregroundStyle(valueColor(value))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            hovered ? LogXTheme.panel2
                : (isEven ? Color.clear : LogXTheme.panel.opacity(0.4))
        )
        .onHover { hovered = $0 }
    }

    private func valueColor(_ val: String) -> Color {
        if val.isEmpty { return LogXTheme.muted2 }
        if val == "true" || val == "false" || val == "null" {
            return JSONHighlighter.spanColor(.boolNull)
        }
        if Double(val) != nil {
            return JSONHighlighter.spanColor(.number)
        }
        return JSONHighlighter.spanColor(.string)
    }
}
