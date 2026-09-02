import SwiftUI
import LogXCore

struct ContentView: View {
    @EnvironmentObject private var store: LogStore
    @AppStorage("logx.sidebarVisible") private var sidebarVisible = true

    var body: some View {
        NavigationSplitView(columnVisibility: visibility) {
            DeviceRail()
                .navigationSplitViewColumnWidth(min: 200, ideal: 248, max: 300)
        } content: {
            RequestList()
                .navigationSplitViewColumnWidth(min: 360, ideal: 560)
        } detail: {
            RequestDetail()
                .navigationSplitViewColumnWidth(min: 300, ideal: 420)
        }
        .navigationSplitViewStyle(.balanced)
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
                .help(store.isPaused ? "Davom ettirish (⌘P)" : "Pauza — yangi so'rovlar qabul qilinmaydi (⌘P)")
                .keyboardShortcut("p", modifiers: .command)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        store.toggleFollowLatest()
                    }
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(store.followLatest ? LogXTheme.accentLight : LogXTheme.text2)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(store.followLatest ? LogXTheme.accent.opacity(0.18) : LogXTheme.well)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(store.followLatest ? LogXTheme.accent.opacity(0.5) : LogXTheme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(store.followLatest ? "Kuzat yoqilgan — yangi so'rov tanlanadi" : "Kuzat — yangi so'rovni tanlash")

                Menu {
                    Button("HAR saqlash") { store.exportHAR() }
                    Button("JSON saqlash") { store.exportJSON() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
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
                .help("Saqlash — HAR yoki JSON")

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
            prompt: "Host, URL, body"
        )
        .onExitCommand {
            store.selectedKey = nil
        }
    }

    private var visibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { sidebarVisible ? .all : .doubleColumn },
            set: { newValue in
                sidebarVisible = (newValue != .doubleColumn && newValue != .detailOnly)
            }
        )
    }

    private var scopeTitle: String {
        let device = store.selectedScope.title
        let app = store.selectedAppId == "all"
            ? "Barcha ilovalar"
            : (store.apps.first(where: { $0.id == store.selectedAppId })?.shortLabel ?? store.selectedAppId)
        return "\(device) · \(app)"
    }
}
