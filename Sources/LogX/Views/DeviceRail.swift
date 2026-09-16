import SwiftUI
import LogXCore

struct DeviceRail: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionTitle("QURILMALAR", icon: "cable.connector")
                        VStack(spacing: 3) {
                            deviceRow(
                                title: "Barcha qurilmalar",
                                subtitle: store.allLogs.isEmpty ? "jonli so'rov yo'q" : "\(store.allLogs.count) ta jonli",
                                icon: "macbook.and.iphone",
                                isOnline: store.hasLiveStream,
                                selected: store.selectedSerial == nil
                            ) {
                                setScope { store.selectAllDevices() }
                            }

                            ForEach(store.devices) { device in
                                deviceRow(
                                    title: device.title,
                                    subtitle: device.serial,
                                    icon: deviceIcon(for: device),
                                    isOnline: store.isStreamLive(serial: device.serial),
                                    selected: store.selectedSerial == device.serial
                                ) {
                                    setScope { store.selectDevice(device.serial) }
                                }
                            }

                            if store.devices.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "cable.connector.slash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(LogXTheme.muted2)
                                    Text("USB yo'q — telefonni ulang")
                                        .font(LogXType.ui(LogXType.body))
                                        .foregroundStyle(LogXTheme.muted2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        sectionTitle("ILOVALAR", icon: "square.grid.2x2")
                        VStack(spacing: 3) {
                            appRow(
                                title: "Barcha ilovalar",
                                pkg: "",
                                count: store.allLogs.count,
                                selected: store.selectedAppId == "all"
                            ) {
                                setScope { store.selectApp("all") }
                            }
                            ForEach(store.liveApps, id: \.app.id) { entry in
                                appRow(
                                    title: entry.app.shortLabel,
                                    pkg: entry.app.pkg,
                                    count: entry.count,
                                    selected: store.selectedAppId == entry.app.id
                                ) {
                                    setScope { store.selectApp(entry.app.id) }
                                }
                            }

                            if store.liveApps.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "hourglass")
                                        .font(.system(size: 12))
                                        .foregroundStyle(LogXTheme.muted2)
                                    Text("Hali so'rov yo'q")
                                        .font(LogXType.ui(LogXType.body))
                                        .foregroundStyle(LogXTheme.muted2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                store.toggleFavoritesOnly()
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: store.favoritesOnly ? "star.fill" : "star")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(store.favoritesOnly ? LogXTheme.warn : LogXTheme.muted2)
                                Text(store.favoritesOnly ? "SEVIMLILAR (faol)" : "SEVIMLILAR")
                                    .font(LogXType.ui(LogXType.meta, .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(store.favoritesOnly ? LogXTheme.text : LogXTheme.muted)
                                Spacer()
                                if store.liveFavoriteCount > 0 {
                                    Text("\(store.liveFavoriteCount)")
                                        .font(LogXType.mono(LogXType.caption, .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(store.favoritesOnly ? LogXTheme.warn.opacity(0.25) : LogXTheme.panel2)
                                        )
                                        .foregroundStyle(store.favoritesOnly ? LogXTheme.warn : LogXTheme.muted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(store.favoritesOnly ? LogXTheme.warn.opacity(0.14) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(store.favoritesOnly ? LogXTheme.warn.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider().overlay(LogXTheme.divider)

            HStack(spacing: 9) {
                ConnectionDot(tint: connectionTint, pulsing: store.connection == .live)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.connection.title)
                        .font(LogXType.mono(LogXType.meta, .semibold))
                        .foregroundStyle(store.connection == .serverDown ? LogXTheme.err : LogXTheme.text)
                        .lineLimit(1)
                    Text(store.connection.subtitle)
                        .font(LogXType.ui(LogXType.caption))
                        .foregroundStyle(LogXTheme.muted2)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if store.connection == .serverDown || store.connection == .reconnecting {
                    Button {
                        Task { await store.start() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .bold))
                            Text("Qayta ulash")
                                .lineLimit(1)
                        }
                        .font(LogXType.ui(LogXType.meta, .semibold))
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(LogXTheme.accentLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LogXTheme.chipOn, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(LogXTheme.chipOnEdge, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(LogXTheme.well)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.connection)
        }
        .background(LogXTheme.panel)
    }

    private func setScope(_ work: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, work)
    }

    private var connectionTint: Color {
        switch store.connection {
        case .live: return LogXTheme.ok
        case .reconnecting, .paused, .connecting, .booting, .noDevice: return LogXTheme.warn
        case .serverDown: return LogXTheme.err
        }
    }

    private func sectionTitle(_ raw: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
            Text(raw)
                .font(LogXType.ui(LogXType.caption, .semibold))
                .tracking(0.6)
        }
        .foregroundStyle(LogXTheme.muted2)
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private func deviceRow(
        title: String,
        subtitle: String?,
        icon: String,
        isOnline: Bool,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        DeviceRowView(
            title: title,
            subtitle: subtitle,
            icon: icon,
            isOnline: isOnline,
            selected: selected,
            action: action
        )
    }

    private func appRow(
        title: String,
        pkg: String,
        count: Int,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        AppRowView(
            title: title,
            pkg: pkg,
            count: count,
            selected: selected,
            action: action
        )
    }

    private func deviceIcon(for device: ConnectedDevice) -> String {
        let name = (device.model + " " + device.product).lowercased()
        if name.contains("tab") || name.contains("pad") || name.contains("sm-x") {
            return "ipad.gen2"
        }
        return "iphone.gen3"
    }
}
