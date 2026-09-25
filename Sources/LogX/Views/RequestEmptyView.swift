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
                    subtitle: store.banner ?? "8787 ishlamayapti — qayta ulanishni bosing."
                ) {
                    reconnectButton
                }
            case .noDevice where store.adbConflict != nil:
                emptyChrome(
                    icon: "lock.trianglebadge.exclamationmark",
                    tint: LogXTheme.warn,
                    title: "USB band",
                    subtitle: store.adbConflict?.subtitle ?? ""
                ) {
                    AdbConflictActions()
                }
            case .noDevice:
                emptyChrome(
                    icon: "cable.connector.slash",
                    tint: LogXTheme.warn,
                    title: "USB yo'q",
                    subtitle: "Kabelni ulang · telefonda USB debugging yoqiq · «Allow USB debugging» bosilgan bo'lsin."
                ) {
                    Button {
                        store.copy("adb devices", what: "buyruq")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal")
                                .font(.system(size: 11, weight: .semibold))
                            Text("adb devices nusxalash")
                                .font(LogXType.ui(LogXType.body, .semibold))
                        }
                        .foregroundStyle(LogXTheme.text2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LogXTheme.panel2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Terminalda tekshiring: qurilma «unauthorized» bo'lsa telefonda ruxsat bering")
                    .padding(.top, 4)
                }
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
                    subtitle: store.banner ?? "Stream uzildi — tiklanmoqda."
                ) {
                    reconnectButton
                }
            case .live, .paused:
                if store.logCount == 0 {
                    emptyChrome(
                        icon: store.connection == .paused ? "pause.circle" : "tray",
                        tint: store.connection == .paused ? LogXTheme.warn : LogXTheme.accentLight,
                        title: store.connection == .paused ? "Pauza" : (store.banner ?? "So'rov yo'q"),
                        subtitle: store.connection == .paused
                            ? (store.pendingWhilePausedCount > 0
                               ? "\(store.pendingWhilePausedCount) ta so'rov buferda — davom etilganda kiradi."
                               : "Yangi so'rovlar buferda to'planadi.")
                            : (store.canUndoClear ? "Ro'yxat tozalandi." : "Ilovani oching — USB stream jonli.")
                    ) {
                        if store.canUndoClear {
                            undoClearButton
                        } else if store.connection == .live {
                            startSteps
                        }
                    }
                } else if store.hasActiveFilter {
                    filterEmpty
                } else if store.scopedLogCount > 0, store.noiseHiddenCount == store.scopedLogCount {
                    noiseEmpty
                } else {
                    usbEmpty
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(LogXMotion.settle, value: store.connection)
        .transition(.opacity)
    }

    private var reconnectButton: some View {
        primaryCTA(icon: "arrow.clockwise", title: "Qayta ulash") {
            Task { await store.start() }
        }
        .padding(.top, 4)
    }

    private var undoClearButton: some View {
        primaryCTA(icon: "arrow.uturn.backward", title: "Tozalashni bekor qilish") {
            LogXMotion.perform(LogXMotion.settle) {
                store.undoClear()
            }
        }
        .keyboardShortcut("k", modifiers: [.command, .option])
        .help("Tozalangan so'rovlarni qaytarish (⌥⌘K)")
        .padding(.top, 4)
    }

    private var startSteps: some View {
        VStack(alignment: .leading, spacing: 9) {
            step(1, "Telefonda kuzatiladigan ilovani oching")
            step(2, "Ilovada tarmoqqa chiqadigan amalni bajaring")
            step(3, "So'rov shu ro'yxatda darhol ko'rinadi")
        }
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private func step(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("\(index)")
                .font(LogXType.mono(LogXType.caption, .bold))
                .foregroundStyle(LogXTheme.accent)
                .frame(width: 18, height: 18)
                .background(LogXTheme.chipOn, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(text)
                .font(LogXType.ui(LogXType.body))
                .foregroundStyle(LogXTheme.text2)
        }
    }

    private func primaryCTA(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(LogXType.ui(LogXType.body, .semibold))
            }
            .foregroundStyle(LogXTheme.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(LogXTheme.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var filterEmpty: some View {
        emptyChrome(
            icon: "line.3.horizontal.decrease.circle",
            tint: LogXTheme.warn,
            title: "Filterga mos so'rov yo'q",
            subtitle: "Jami \(store.logCount) ta jonli — boshqa ilova yoki status."
        ) {
            primaryCTA(icon: "arrow.counterclockwise", title: "Filtrlarni tozalash") {
                LogXMotion.perform(LogXMotion.settle) {
                    store.clearFilters()
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var noiseEmpty: some View {
        emptyChrome(
            icon: "waveform.slash",
            tint: LogXTheme.warn,
            title: "Hammasi shovqin",
            subtitle: "\(store.noiseHiddenCount) ta so'rov analitika/health sifatida yashirilgan."
        ) {
            primaryCTA(icon: "eye", title: "Shovqinni ko'rsatish") {
                LogXMotion.perform(LogXMotion.settle) {
                    store.toggleHideNoise()
                }
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
            subtitle: "Jami \(store.logCount) ta jonli — boshqa ulangan qurilma."
        ) {
            primaryCTA(icon: "macbook.and.iphone", title: "Barchasini ko'rish") {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    store.selectAllDevices()
                }
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(tint)
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(LogXType.ui(LogXType.title, .semibold))
                    .foregroundStyle(LogXTheme.text)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(LogXType.ui(LogXType.body))
                    .foregroundStyle(LogXTheme.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
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
