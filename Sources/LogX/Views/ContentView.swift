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
                .help(store.isPaused ? "Davom ettirish (⌘P)" : "Pauza — yangi so'rovlar buferda to'planadi (⌘P)")
                .accessibilityLabel(store.isPaused ? "Davom ettirish" : "Pauza")
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
                .help(store.followLatest ? "Kuzat yoqilgan — yangi so'rov tanlanadi (⌘L)" : "Kuzat — yangi so'rovni tanlash (⌘L)")
                .accessibilityLabel("Kuzat")
                .accessibilityValue(store.followLatest ? "yoqilgan" : "o'chirilgan")

                Menu {
                    Button("HAR saqlash") { store.exportHAR() }
                    Button("JSON saqlash") { store.exportJSON() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(store.canExport ? LogXTheme.muted : LogXTheme.muted2)
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
                .disabled(!store.canExport)
                .help(store.canExport ? "Saqlash — ko'rinadigan sessiya HAR yoki JSON" : "Saqlash uchun ko'rinadigan so'rov yo'q")
                .accessibilityLabel("Sessiyani saqlash")

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
                .disabled(store.allLogs.isEmpty)
                .help("Ro'yxatni tozalash (⌘K)")
                .accessibilityLabel("Ro'yxatni tozalash")
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .onExitCommand {
            store.clearSelection()
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

/// Menyu → ko'rinish fokus buyruqlari (⌘F ro'yxat qidiruvi, ⌥⌘F JSON topish).
enum LogXNotice {
    static let focusListSearch = Notification.Name("logx.focusListSearch")
    static let focusDetailFind = Notification.Name("logx.focusDetailFind")
}
