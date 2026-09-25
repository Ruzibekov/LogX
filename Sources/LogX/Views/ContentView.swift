import SwiftUI
import LogXCore

struct ContentView: View {
    @EnvironmentObject private var store: LogStore
    @AppStorage("logx.sidebarVisible") private var sidebarVisible = true

    @State private var now = Date()
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
        HStack(spacing: 0) {
            if sidebarVisible {
                DeviceRail()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            HSplitView {
                RequestList()
                    .frame(minWidth: 380, idealWidth: 460, maxWidth: 620)
                RequestDetail()
                    .frame(minWidth: 460, maxWidth: .infinity)
                    .sheet(item: Binding(get: { store.replayComposerLog }, set: { store.replayComposerLog = $0 })) { log in
                        ReplayComposerView(log: log)
                            .environmentObject(store)
                    }
            }
        }
        RequestLiveBar(now: now)
        }
        .onReceive(ticker) { now = $0 }
        .background(LogXTheme.bg)
        .sheet(item: Binding(get: { store.diffPair }, set: { store.diffPair = $0 })) { pair in
            DiffView(pair: pair)
                .environmentObject(store)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                titleBarIcon("sidebar.leading", active: sidebarVisible, help: sidebarVisible ? "Qurilma reykini yashirish" : "Qurilma reykini ko'rsatish", label: "Qurilma reyki") {
                    LogXMotion.perform(LogXMotion.snappy) {
                        sidebarVisible.toggle()
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                ToolbarTitle(scopeTitle: scopeTitle)
            }
            ToolbarItem(placement: .primaryAction) {
                ToolbarActions()
            }
        }
    }

    private func titleBarIcon(
        _ icon: String,
        active: Bool,
        help: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(active ? LogXTheme.accent : LogXTheme.muted)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                        .fill(active ? LogXTheme.chipOn : Color.clear)
                )
        }
        .buttonStyle(LogXPressStyle())
        .help(help)
        .accessibilityLabel(label)
        .accessibilityValue(active ? "yoqilgan" : "o'chirilgan")
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

enum LogXNotice {
    static let focusListSearch = Notification.Name("logx.focusListSearch")
    static let focusDetailFind = Notification.Name("logx.focusDetailFind")
    static let focusList = Notification.Name("logx.focusList")
    static let zoomIn = Notification.Name("logx.zoomIn")
    static let zoomOut = Notification.Name("logx.zoomOut")
    static let zoomReset = Notification.Name("logx.zoomReset")
}

struct ToolbarTitle: View {
    @EnvironmentObject private var store: LogStore
    var scopeTitle: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LogXTheme.accent)
                Text("LogX")
                    .font(LogXType.ui(LogXType.title, .bold))
                    .foregroundStyle(LogXTheme.text)
            }
            HStack(spacing: 8) {
                LiveDot(tint: store.connection == .live ? LogXTheme.ok : LogXTheme.muted, pulsing: store.connection == .live, size: 6)
                Text(scopeTitle)
                    .font(LogXType.mono(11))
                    .foregroundStyle(LogXTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                    .stroke(LogXTheme.line, lineWidth: 1)
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ToolbarActions: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        HStack(spacing: 8) {
            Button {
                LogXMotion.perform(LogXMotion.snappy) {
                    store.toggleFollowLatest()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Kuzat")
                        .font(LogXType.ui(12.5, .medium))
                }
            }
            .buttonStyle(LogXButtonStyle(kind: store.followLatest ? .tinted : .outline))
            .help(store.followLatest ? "Kuzat yoqilgan — eng yangi so'rov tepada ko'rinadi (⌘L)" : "Kuzat — yangi so'rovni kuzatish (⌘L)")
            .accessibilityLabel("Kuzat")
            .accessibilityValue(store.followLatest ? "yoqilgan" : "o'chirilgan")

            Button {
                Task { await store.start() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Qayta ulash")
                        .font(LogXType.ui(12.5, .medium))
                }
            }
            .buttonStyle(LogXButtonStyle(kind: .outline))
            .help("Monitorga qayta ulanish")
            .accessibilityLabel("Qayta ulash")

            Menu {
                Button("HAR saqlash") { store.exportHAR() }
                Button("JSON saqlash") { store.exportJSON() }
            } label: {
                outlinedIcon("square.and.arrow.down", tint: store.canExport ? LogXTheme.text2 : LogXTheme.muted2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30, height: 30)
            .disabled(!store.canExport)
            .help(store.canExport ? "Saqlash — ko'rinadigan sessiya HAR yoki JSON" : "Saqlash uchun ko'rinadigan so'rov yo'q")
            .accessibilityLabel("Sessiyani saqlash")

            Menu {
                Button(store.redactEnabled ? "Tokenlarni ko'rsatish" : "Tokenlarni yashirish") { store.redactEnabled.toggle() }
                Button(store.hideNoise ? "Shovqinni ko'rsatish" : "Shovqinni yashirish") { store.toggleHideNoise() }
                Divider()
                Button("Ro'yxatni tozalash") { store.clearLogs() }
                    .disabled(store.logCount == 0)
                Button("Tozalashni bekor qilish") { store.undoClear() }
                    .disabled(!store.canUndoClear)
            } label: {
                outlinedIcon("gearshape", tint: LogXTheme.text2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30, height: 30)
            .help("Ko'rinish sozlamalari")
            .accessibilityLabel("Sozlamalar")
        }
    }

    private func outlinedIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                    .stroke(LogXTheme.line, lineWidth: 1)
            )
    }
}
