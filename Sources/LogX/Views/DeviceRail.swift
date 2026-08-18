import SwiftUI
import LogXCore

struct DeviceRail: View {
    @EnvironmentObject private var store: LogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("USB / LIVE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(LogXTheme.muted)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            PortRow(
                title: "Barchasi",
                subtitle: store.allLogs.isEmpty ? "live so‘rov yo‘q" : "\(store.allLogs.count) ta live",
                live: !store.allLogs.isEmpty,
                selected: store.selectedSerial == nil
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    store.selectAllDevices()
                }
            }

            if store.devices.isEmpty {
                Text("USB yo‘q — telefonni ulang")
                    .font(.system(size: 12))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ForEach(store.devices) { device in
                PortRow(
                    title: device.title,
                    subtitle: device.serial,
                    live: true,
                    selected: store.selectedSerial == device.serial
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        store.selectDevice(device.serial)
                    }
                }
            }

            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(store.serverOK ? LogXTheme.ok : LogXTheme.err)
                    .frame(width: 7, height: 7)
                Text(store.serverOK ? "8787" : "server yo‘q")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
            }
            .padding(10)
        }
        .padding(8)
        .background(LogXTheme.panel)
    }
}

private struct PortRow: View {
    var title: String
    var subtitle: String
    var live: Bool
    var selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(live ? LogXTheme.ok : LogXTheme.muted)
                .frame(width: 8, height: 8)
                .shadow(color: live ? LogXTheme.ok.opacity(0.55) : .clear, radius: selected ? 5 : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LogXTheme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? LogXTheme.select : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? LogXTheme.ember.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
