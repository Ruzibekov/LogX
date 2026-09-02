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
                                selected: store.selectedSerial == nil && store.selectedFieldId == nil
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
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(LogXTheme.muted2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        sectionTitle("ILLOVALAR", icon: "square.grid.2x2")
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
                                        .font(.system(size: 11.5))
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
                                Text(store.favoritesOnly ? "★ SEVIMLILAR (faol)" : "★ SEVIMLILAR")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .tracking(0.9)
                                    .foregroundStyle(store.favoritesOnly ? LogXTheme.text : LogXTheme.muted)
                                Spacer()
                                if !store.favoriteKeys.isEmpty {
                                    Text("\(store.favoriteKeys.count)")
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(store.favoritesOnly ? LogXTheme.warn.opacity(0.25) : LogXTheme.panel2)
                                        )
                                        .foregroundStyle(store.favoritesOnly ? LogXTheme.warn : LogXTheme.muted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(store.favoritesOnly ? LogXTheme.warn.opacity(0.14) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(store.connection == .serverDown ? LogXTheme.err : LogXTheme.text)
                    Text(store.connection.subtitle)
                        .font(.system(size: 9.5))
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
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(LogXTheme.accentLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LogXTheme.accent.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(LogXTheme.accent.opacity(0.4), lineWidth: 1))
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
                .font(.system(size: 10, weight: .bold))
                .tracking(1.0)
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

private struct DeviceRowView: View {
    var title: String
    var subtitle: String?
    var icon: String
    var isOnline: Bool
    var selected: Bool
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(selected ? LogXTheme.accentLight : (isOnline ? LogXTheme.ok : LogXTheme.muted2))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(title)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? LogXTheme.text : LogXTheme.text2)
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(LogXTheme.muted2)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if selected {
                    Circle()
                        .fill(LogXTheme.accentLight)
                        .frame(width: 5, height: 5)
                        .shadow(color: LogXTheme.accent.opacity(0.8), radius: 4)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? LogXTheme.accent.opacity(0.18) : (hovered ? LogXTheme.panel2 : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected ? LogXTheme.accent.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct AppRowView: View {
    var title: String
    var pkg: String
    var count: Int
    var selected: Bool
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(selected ? LogXTheme.accentLight : LogXTheme.muted)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? LogXTheme.text : LogXTheme.text2)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(selected ? LogXTheme.accentLight : LogXTheme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(selected ? LogXTheme.accent.opacity(0.25) : LogXTheme.well)
                    )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? LogXTheme.accent.opacity(0.18) : (hovered ? LogXTheme.panel2 : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected ? LogXTheme.accent.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
