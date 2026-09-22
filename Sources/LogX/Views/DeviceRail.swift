import SwiftUI
import LogXCore

struct DeviceRail: View {
    @EnvironmentObject private var store: LogStore

    static let width: CGFloat = 56

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
                    .foregroundStyle(LogXTheme.muted2)
                    .frame(width: 40, height: 40)
                    .help("USB yo'q — telefonni ulang")
            }

            Spacer(minLength: 8)

            appsMenu
            favoritesButton
            settingsMenu
        }
        .padding(.vertical, 12)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LogXTheme.panel)
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
                .font(LogXType.mono(LogXType.meta, .bold))
                .foregroundStyle(selected ? LogXTheme.accent : LogXTheme.text2)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? LogXTheme.chipOn : LogXTheme.panel2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? LogXTheme.chipOnEdge : LogXTheme.line, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if online {
                        Circle()
                            .fill(LogXTheme.ok)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(LogXTheme.panel, lineWidth: 1.5))
                            .offset(x: 3, y: -3)
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
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { store.toggleFavoritesOnly() }
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
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? tint.opacity(0.14) : Color.clear)
            )
    }
}
