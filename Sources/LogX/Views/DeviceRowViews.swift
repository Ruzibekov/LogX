import SwiftUI
import LogXCore

struct DeviceRowView: View {
    var title: String
    var subtitle: String?
    var icon: String
    var isOnline: Bool
    var selected: Bool
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(selected ? LogXTheme.accentLight : (isOnline ? LogXTheme.ok : LogXTheme.muted2))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(title)
                        .font(LogXType.ui(LogXType.body, selected ? .semibold : .medium))
                        .foregroundStyle(selected ? LogXTheme.text : LogXTheme.text2)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(LogXType.mono(LogXType.caption))
                            .foregroundStyle(LogXTheme.muted2)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? LogXTheme.chipOn : (hovered ? LogXTheme.panel2 : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct AppRowView: View {
    var title: String
    var pkg: String
    var count: Int
    var selected: Bool
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(selected ? LogXTheme.accentLight : LogXTheme.muted)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(LogXType.ui(LogXType.body, selected ? .semibold : .medium))
                        .foregroundStyle(selected ? LogXTheme.text : LogXTheme.text2)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(LogXType.mono(LogXType.caption, .bold))
                    .foregroundStyle(selected ? LogXTheme.accentLight : LogXTheme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(selected ? LogXTheme.chipOn : LogXTheme.well)
                    )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? LogXTheme.chipOn : (hovered ? LogXTheme.panel2 : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
