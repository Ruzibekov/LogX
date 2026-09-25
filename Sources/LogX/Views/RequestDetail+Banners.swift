import SwiftUI
import LogXCore

extension RequestDetail {
    var hiddenBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 10.5, weight: .semibold))
            Text("Bu so'rov joriy filtr bilan ro'yxatda ko'rinmaydi")
                .font(LogXType.ui(11.5, .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            Button("Filtrlarni tozalash") {
                LogXMotion.perform(LogXMotion.settle) {
                    store.clearFilters()
                }
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .font(LogXType.ui(11.5, .semibold))
            .foregroundStyle(LogXTheme.accentLight)
        }
        .foregroundStyle(LogXTheme.warn)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LogXTheme.warn.opacity(0.1))
    }

    func truncationStrip(_ notice: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "scissors")
                .font(.system(size: 10, weight: .semibold))
            Text(notice)
                .font(LogXType.ui(11, .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(LogXTheme.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(LogXTheme.panel2)
        .clipShape(Rectangle())
    }

    var bodyWell: some View {
        RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
            .fill(LogXTheme.well)
            .overlay(
                RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                    .stroke(LogXTheme.line, lineWidth: 1)
            )
    }

    var codeWell: some View {
        Rectangle().fill(LogXTheme.well)
    }

    var noSelectionPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 32))
                .foregroundStyle(LogXTheme.muted2)
            Text("So'rov tanlang")
                .font(LogXType.ui(LogXType.title, .medium))
                .foregroundStyle(LogXTheme.muted)
            Text("↑↓ bilan yuring, ⌘F qidiradi")
                .font(LogXType.ui(LogXType.meta))
                .foregroundStyle(LogXTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
