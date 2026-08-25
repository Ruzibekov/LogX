import SwiftUI
import LogXCore

struct ContentView: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        NavigationSplitView {
            DeviceRail()
                .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 320)
        } content: {
            RequestList()
                .navigationSplitViewColumnWidth(min: 440, ideal: 660, max: 920)
        } detail: {
            RequestDetail()
                .navigationSplitViewColumnWidth(min: 340, ideal: 440, max: 680)
        }
        .background(LogXTheme.bg)
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(LogXTheme.accentLight)
                    Text(scopeTitle)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(LogXTheme.text2)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LogXTheme.well)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(LogXTheme.line, lineWidth: 1)
                        )
                )
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        store.togglePause()
                    }
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(store.isPaused ? LogXTheme.warn : LogXTheme.text2)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(store.isPaused ? LogXTheme.warn.opacity(0.18) : LogXTheme.well)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(store.isPaused ? LogXTheme.warn.opacity(0.5) : LogXTheme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(store.isPaused ? "Davom ettirish" : "Pauza — yangi so'rovlar qabul qilinmaydi")

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        store.clearLogs()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LogXTheme.muted)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LogXTheme.well)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(LogXTheme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Ro'yxatni tozalash (⌘K)")
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .searchable(
            text: Binding(
                get: { store.query },
                set: { store.applyQuery($0) }
            ),
            prompt: "URL, metod, status…"
        )
        .onExitCommand {
            store.selectedKey = nil
        }
    }

    private var scopeTitle: String {
        let device = store.selectedScope.title
        let app = store.selectedAppId == "all"
            ? "Barcha ilovalar"
            : (store.apps.first(where: { $0.id == store.selectedAppId })?.shortLabel ?? store.selectedAppId)
        return "\(device) · \(app)"
    }
}
