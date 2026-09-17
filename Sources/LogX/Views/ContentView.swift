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
                    .frame(minWidth: 420, maxWidth: .infinity)
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
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        sidebarVisible.toggle()
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(LogXTheme.accent)
                    Text("LogX")
                        .font(LogXType.ui(LogXType.title, .bold))
                        .foregroundStyle(LogXTheme.text)
                    Text(scopeTitle)
                        .font(LogXType.mono(LogXType.meta))
                        .foregroundStyle(LogXTheme.muted)
                        .lineLimit(1)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                titleBarIcon(
                    "arrow.down.to.line",
                    active: store.followLatest,
                    help: store.followLatest ? "Kuzat yoqilgan — eng yangi so'rov tepada ko'rinadi (⌘L)" : "Kuzat — yangi so'rovni kuzatish (⌘L)",
                    label: "Kuzat"
                ) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        store.toggleFollowLatest()
                    }
                }

                titleBarIcon(
                    "arrow.clockwise",
                    active: false,
                    help: "Monitorga qayta ulanish",
                    label: "Qayta ulash"
                ) {
                    Task { await store.start() }
                }

                Menu {
                    Button("HAR saqlash") { store.exportHAR() }
                    Button("JSON saqlash") { store.exportJSON() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(store.canExport ? LogXTheme.muted : LogXTheme.muted2)
                        .frame(width: 30, height: 30)
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
                        .disabled(store.allLogs.isEmpty)
                    Button("Tozalashni bekor qilish") { store.undoClear() }
                        .disabled(!store.canUndoClear)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(LogXTheme.muted)
                        .frame(width: 30, height: 30)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 30, height: 30)
                .help("Ko'rinish sozlamalari")
                .accessibilityLabel("Sozlamalar")
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
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
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
