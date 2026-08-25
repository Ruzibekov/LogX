import SwiftUI
import LogXCore

struct RequestEmptyView: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        Group {
            switch store.connection {
            case .serverDown:
                emptyChrome(
                    icon: "wifi.slash",
                    tint: LogXTheme.err,
                    title: "Monitor yo'q",
                    subtitle: "8787 ishlamayapti — qayta ulanishni bosing."
                ) {
                    reconnectButton
                }
            case .noDevice:
                emptyChrome(
                    icon: "cable.connector.slash",
                    tint: LogXTheme.warn,
                    title: "USB yo'q",
                    subtitle: "Telefonni kabel bilan ulang."
                )
            case .booting, .connecting:
                emptyChrome(
                    icon: "dot.radiowaves.left.and.right",
                    tint: LogXTheme.warn,
                    title: store.connection.title,
                    subtitle: store.connection.subtitle
                )
            case .reconnecting:
                emptyChrome(
                    icon: "arrow.triangle.2.circlepath",
                    tint: LogXTheme.warn,
                    title: "Qayta ulanmoqda…",
                    subtitle: "Stream uzildi — tiklanmoqda."
                ) {
                    reconnectButton
                }
            case .live, .paused:
                if store.allLogs.isEmpty {
                    emptyChrome(
                        icon: store.connection == .paused ? "pause.circle" : "tray",
                        tint: store.connection == .paused ? LogXTheme.warn : LogXTheme.accentLight,
                        title: store.connection == .paused ? "Pauza" : (store.banner ?? "So'rov yo'q"),
                        subtitle: store.connection == .paused
                            ? (store.skippedWhilePaused > 0
                               ? "\(store.skippedWhilePaused) ta so'rov o'tkazib yuborildi."
                               : "Yangi so'rovlar qabul qilinmaydi.")
                            : "Ilovani oching — USB stream jonli."
                    )
                } else if store.hasActiveFilter {
                    filterEmpty
                } else {
                    usbEmpty
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.connection)
        .transition(.opacity)
    }

    private var reconnectButton: some View {
        Button {
            Task { await store.start() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                Text("Qayta ulash")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(LogXTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(LogXTheme.accent))
            .shadow(color: LogXTheme.accent.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var filterEmpty: some View {
        emptyChrome(
            icon: "line.3.horizontal.decrease.circle",
            tint: LogXTheme.warn,
            title: "Filterga mos so'rov yo'q",
            subtitle: "Jami \(store.allLogs.count) ta jonli — boshqa ilova yoki status."
        ) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    store.clearFilters()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("Filtrlarni tozalash")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(LogXTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(LogXTheme.accent))
                .shadow(color: LogXTheme.accent.opacity(0.4), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var usbEmpty: some View {
        emptyChrome(
            icon: "cable.connector",
            tint: LogXTheme.method,
            title: "Bu USB da jonli so'rov yo'q",
            subtitle: "Jami \(store.allLogs.count) ta jonli — boshqa ulangan qurilma."
        ) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    store.selectAllDevices()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "macbook.and.iphone")
                        .font(.system(size: 11, weight: .bold))
                    Text("Barchasini ko'rish")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(LogXTheme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(LogXTheme.accent))
                .shadow(color: LogXTheme.accent.opacity(0.4), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func emptyChrome<Extra: View>(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(tint)
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LogXTheme.text)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(LogXTheme.muted)
                    .multilineTextAlignment(.center)
            }
            extra()
        }
    }

    private func emptyChrome(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String
    ) -> some View {
        emptyChrome(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}
