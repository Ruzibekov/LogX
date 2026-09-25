import SwiftUI
import LogXCore

struct AdbConflictActions: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { reclaimButton; copyButton }
            VStack(spacing: 8) { reclaimButton; copyButton }
        }
        .padding(.top, 4)
    }

    private var reclaimButton: some View {
        Button {
            store.reclaimAdb()
        } label: {
            HStack(spacing: 6) {
                if store.adbReclaimInFlight {
                    ProgressView()
                        .controlSize(.small)
                        .tint(LogXTheme.onAccent)
                } else {
                    Image(systemName: "bolt.horizontal.circle")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(store.adbReclaimInFlight ? "Bo'shatilmoqda…" : "Qurilmani bo'shatish")
                    .font(LogXType.ui(LogXType.body, .semibold))
                    .fixedSize()
            }
            .foregroundStyle(LogXTheme.onAccent)
            .padding(.horizontal, 16)
            .frame(minHeight: 32)
            .background(LogXTheme.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!store.adbReclaimInFlight)
        .help("Begona adb serverni to'xtatib, 5037-portdagi adb'ni qayta ishga tushiradi")
    }

    private var copyButton: some View {
        Button {
            store.copy(store.adbConflict?.fix ?? "", what: "buyruq")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                Text("Buyruqni nusxalash")
                    .font(LogXType.ui(LogXType.body, .semibold))
                    .fixedSize()
            }
            .foregroundStyle(LogXTheme.text2)
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(LogXTheme.panel2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(store.adbConflict?.fix ?? "")
    }
}
