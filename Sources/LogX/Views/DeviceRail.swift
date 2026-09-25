import SwiftUI
import LogXCore

struct DeviceRail: View {
    @EnvironmentObject private var store: LogStore

    static let width: CGFloat = 56
    static let avatar: CGFloat = 38

    var body: some View {
        VStack(spacing: 10) {
            deviceAvatar(
                label: "ALL",
                title: "Barcha qurilmalar",
                subtitle: store.logCount == 0 ? "jonli so'rov yo'q" : "\(store.logCount) ta jonli",
                online: store.hasLiveStream,
                selected: store.selectedSerial == nil
            ) {
                setScope { store.selectAllDevices() }
            }

            ForEach(store.devices) { device in
                deviceAvatar(
                    label: DeviceBadge.initials(device.title),
                    title: device.title,
                    subtitle: device.serial,
                    online: store.isStreamLive(serial: device.serial),
                    selected: store.selectedSerial == device.serial
                ) {
                    setScope { store.selectDevice(device.serial) }
                }
            }

            if store.devices.isEmpty {
                Image(systemName: "cable.connector.slash")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(LogXTheme.muted)
                    .frame(width: 38, height: 38)
                    .help(store.adbConflict == nil ? "USB yo'q — telefonni ulang" : "USB band — boshqa adb server qurilmani ushlab turibdi")
            }

            Spacer(minLength: 8)

            appsMenu
            favoritesButton
            settingsMenu
        }
        .padding(.vertical, 12)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LogXTheme.chrome)
        .overlay(alignment: .trailing) { Rectangle().fill(LogXTheme.line).frame(width: 1) }
    }

    private func setScope(_ work: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, work)
    }

    private func deviceAvatar(
        label: String,
        title: String,
        subtitle: String,
        online: Bool,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(LogXType.ui(LogXType.meta, .bold))
                .foregroundStyle(selected ? LogXTheme.onAccent : LogXTheme.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: Self.avatar, height: Self.avatar)
                .background(
                    RoundedRectangle(cornerRadius: LogXRadius.avatar, style: .continuous)
                        .fill(selected ? LogXTheme.accent : LogXTheme.panel2)
                )
                .overlay(alignment: .bottomTrailing) {
                    if online {
                        Circle()
                            .fill(LogXTheme.ok)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(LogXTheme.chrome, lineWidth: 2))
                            .offset(x: 1, y: 1)
                    }
                }
        }
        .buttonStyle(LogXPressStyle())
        .help("\(title) · \(subtitle)")
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "tanlangan" : subtitle)
    }

    private var appsMenu: some View {
        Menu {
            Button {
                setScope { store.selectApp("all") }
            } label: {
                if store.selectedAppId == "all" {
                    Label("Barcha ilovalar · \(store.logCount)", systemImage: "checkmark")
                } else {
                    Text("Barcha ilovalar · \(store.logCount)")
                }
            }
            if !store.liveApps.isEmpty { Divider() }
            ForEach(store.liveApps, id: \.app.id) { entry in
                Button {
                    setScope { store.selectApp(entry.app.id) }
                } label: {
                    if store.selectedAppId == entry.app.id {
                        Label("\(entry.app.shortLabel) · \(entry.count)", systemImage: "checkmark")
                    } else {
                        Text("\(entry.app.shortLabel) · \(entry.count)")
                    }
                }
            }
            if store.liveApps.isEmpty {
                Text("Hali so'rov yo'q").font(LogXType.ui(LogXType.meta))
            }
        } label: {
            railIcon("square.grid.2x2", active: store.selectedAppId != "all")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 34, height: 34)
        .help(store.selectedAppId == "all" ? "Ilovalar — filtrlash" : "Ilova filtri yoqilgan")
        .accessibilityLabel("Ilovalar")
    }

    private var favoritesButton: some View {
        Button {
            LogXMotion.perform(LogXMotion.snappy) { store.toggleFavoritesOnly() }
        } label: {
            railIcon(store.favoritesOnly ? "star.fill" : "star", active: store.favoritesOnly, tint: LogXTheme.warn)
                .overlay(alignment: .topTrailing) {
                    if store.liveFavoriteCount > 0, !store.favoritesOnly {
                        Text("\(store.liveFavoriteCount)")
                            .font(LogXType.mono(LogXType.caption, .bold))
                            .foregroundStyle(LogXTheme.muted)
                            .offset(x: 6, y: -4)
                    }
                }
        }
        .buttonStyle(LogXPressStyle())
        .help(store.favoritesOnly ? "Sevimlilar filtri yoqilgan" : "Faqat sevimlilarni ko'rsatish")
        .accessibilityLabel("Sevimlilar")
        .accessibilityValue(store.favoritesOnly ? "yoqilgan" : "o'chirilgan")
    }

    private var settingsMenu: some View {
        Menu {
            Button(store.redactEnabled ? "Tokenlarni ko'rsatish" : "Tokenlarni yashirish") { store.redactEnabled.toggle() }
            Divider()
            Button("HAR saqlash") { store.exportHAR() }
                .disabled(!store.canExport)
            Button("JSON saqlash") { store.exportJSON() }
                .disabled(!store.canExport)
            Divider()
            Button("Qayta ulash") { Task { await store.start() } }
        } label: {
            railIcon("gearshape", active: false)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 34, height: 34)
        .help("Sozlamalar va saqlash")
        .accessibilityLabel("Sozlamalar")
    }

    private func railIcon(_ name: String, active: Bool, tint: Color = LogXTheme.accent) -> some View {
        Image(systemName: name)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(active ? tint : LogXTheme.muted)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                    .fill(active ? (tint == LogXTheme.accent ? LogXTheme.chipOn : tint.opacity(0.12)) : Color.clear)
            )
    }
}
