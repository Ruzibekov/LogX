import AppKit
import SwiftUI
import LogXCore

struct DetailHeader: View {
    @EnvironmentObject private var store: LogStore
    var log: NetworkLog
    var tab: DetailTab
    var onCopyBody: () -> Void = {}
    var onShare: () -> Void = {}
    @State private var urlCopied = false
    @AppStorage("logx.detailHeaderCollapsed") private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCollapsed ? 7 : 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(log.method)
                    .font(LogXType.mono(LogXType.meta, .bold))
                    .foregroundStyle(LogXTheme.methodColor(log.method))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(LogXTheme.panel2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(URLHighlighter.attributed(store.shareableURL(log), baseFontSize: LogXType.title))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(store.shareableURL(log))

                copyURLButton

                Spacer(minLength: 10)

                actions
            }

            metaLine

            if !isCollapsed, !identityChips.isEmpty {
                WrapLayout(spacing: 14, lineSpacing: 5) {
                    ForEach(identityChips, id: \.key) { chip in
                        metaPair(chip.key, chip.value)
                    }
                }
            }

            if let msg = problemMessage {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(msg)
                        .font(LogXType.ui(LogXType.body))
                }
                .foregroundStyle(LogXTheme.warn)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LogXTheme.warn.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LogXTheme.panel)
    }

    private var actions: some View {
        HStack(spacing: 7) {
            actionPill(
                store.selectedIsReplaying ? "Yuborilmoqda…" : "Qayta yuborish",
                icon: "arrow.clockwise",
                primary: true,
                help: store.replayBlocker(log) ?? "So'rovni Mac'dan qayta yuborish — javob ro'yxatga REPLAY bo'lib tushadi (⌘⏎)"
            ) {
                store.replay(log)
            }
            .disabled(!store.canReplay(log))
            .keyboardShortcut(.return, modifiers: .command)

            actionPill("Farq", icon: "arrow.left.arrow.right", help: diffHelp) {
                if let anchor = store.diffAnchor, anchor.key != log.key {
                    store.compareWithAnchor(log)
                } else {
                    store.toggleDiffAnchor(log)
                }
            }

            actionPill("cURL", icon: "terminal", help: "cURL buyrug'ini nusxalash (⌘⇧C)") {
                store.copy(CurlBuilder.command(for: log, redact: store.redactEnabled), what: "cURL")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            actionPill("Ulashish", icon: "square.and.arrow.up", help: "Rasm sifatida ulashish") {
                onShare()
            }

            Menu {
                Button("Tanani nusxalash") { onCopyBody() }
                Button("Tahrirlab yuborish") { store.openReplayComposer(log) }
                    .disabled(!store.canReplay(log))
                Divider()
                Button(store.isFavorite(log.key) ? "Sevimlilardan olib tashlash" : "Sevimlilarga qo'shish") {
                    store.toggleFavorite(log.key)
                }
                Button(store.redactEnabled ? "Tokenlarni ko'rsatish" : "Tokenlarni yashirish") {
                    store.redactEnabled.toggle()
                }
                if store.previousSameEndpoint(of: log) != nil {
                    Button("Oldingi bir xil so'rov bilan solishtirish") { store.compareWithPrevious(log) }
                }
                Divider()
                Button(isCollapsed ? "Batafsil ko'rsatish" : "Ixcham rejim") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { isCollapsed.toggle() }
                }
            } label: {
                Image(systemName: store.isFavorite(log.key) ? "star.fill" : "ellipsis")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(store.isFavorite(log.key) ? LogXTheme.warn : LogXTheme.muted)
                    .frame(width: 30, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(LogXTheme.panel2))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30, height: 28)
            .help("Boshqa amallar")
            .accessibilityLabel("Boshqa amallar")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var diffHelp: String {
        if let anchor = store.diffAnchor, anchor.key != log.key {
            return "A bilan solishtirish · \(anchor.method) \(anchor.pathOnly) (⇧⌘D)"
        }
        return store.diffAnchorKey == log.key ? "A belgisini olib tashlash (⌘D)" : "Solishtirish uchun A deb belgilash (⌘D)"
    }

    private func actionPill(
        _ title: String,
        icon: String,
        primary: Bool = false,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(LogXType.ui(LogXType.meta, .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(primary ? LogXTheme.accent : LogXTheme.text2)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(primary ? LogXTheme.chipOn : LogXTheme.panel2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(primary ? LogXTheme.chipOnEdge : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(LogXPressStyle())
        .help(help)
        .accessibilityLabel(title)
    }

    private var copyURLButton: some View {
        Button {
            store.copy(store.shareableURL(log), what: "URL")
            urlCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { urlCopied = false }
        } label: {
            Image(systemName: urlCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(urlCopied ? LogXTheme.ok : LogXTheme.muted2)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help("URL nusxalash")
        .accessibilityLabel("URL nusxalash")
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            Text(log.responseCode.map { "\($0) \(log.statusDescription)" } ?? log.statusDescription)
                .font(LogXType.mono(LogXType.meta, .bold))
                .foregroundStyle(LogXTheme.status(log.statusClass))
                .lineLimit(1)

            ForEach(metaFacts, id: \.self) { fact in
                Text("·")
                    .font(LogXType.mono(LogXType.meta))
                    .foregroundStyle(LogXTheme.muted2)
                Text(fact)
                    .font(LogXType.mono(LogXType.meta))
                    .foregroundStyle(LogXTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(scopeLabel)
                .font(LogXType.mono(LogXType.caption))
                .foregroundStyle(LogXTheme.muted2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var metaFacts: [String] {
        var out: [String] = []
        if log.durationMs != nil { out.append(log.formattedDuration) }
        out.append(bodySizeLabel(log))
        out.append(RelativeTime.stamp(ts: log.ts))
        let repeats = store.repeatCount(for: log)
        if repeats > 1 { out.append("×\(repeats)") }
        if !isCollapsed, let env = log.environment, !env.isEmpty {
            out.append([env, log.flavor, log.appVersion].compactMap { $0 }.joined(separator: " "))
        }
        if !isCollapsed, let feature = log.feature, !feature.isEmpty {
            out.append(log.moduleName ?? feature)
        }
        return out
    }

    private var scopeLabel: String {
        let device = deviceLabel
        return device == "—" ? log.appLabel : "\(log.appLabel) · \(device)"
    }

    private var deviceLabel: String {
        let label = log.fieldDeviceLabel
        if label != "—" { return label }
        if let serial = log.serial, !serial.isEmpty { return serial }
        return label
    }

    private var identityChips: [(key: String, value: String)] {
        let redact = store.redactEnabled
        var out: [(key: String, value: String)] = []
        if let pinfl = log.userInfoPinfl ?? log.assistantJshshir, !pinfl.isEmpty {
            out.append(("PINFL", redact ? Redactor.placeholder : pinfl))
        }
        if let sid = log.sessionId, !sid.isEmpty {
            out.append(("Sessiya", redact ? Redactor.placeholder : sid))
        }
        if let did = log.requestHeaders["device-id"], !did.isEmpty {
            out.append(("device-id", redact ? Redactor.placeholder : did))
        }
        return out
    }

    private var problemMessage: String? {
        if let err = log.error, !err.isEmpty { return err }
        guard log.statusClass != .ok2xx, log.statusClass != .redirect3xx else { return nil }
        let msg = log.responseBodyMessage ?? log.responseMessage
        guard let msg, !msg.isEmpty else { return nil }
        if msg.caseInsensitiveCompare(log.statusDescription) == .orderedSame { return nil }
        return msg
    }

    private func metaPair(_ k: String, _ v: String) -> some View {
        let masked = v.contains("••")
        return Button {
            store.copy(v, what: k)
        } label: {
            HStack(spacing: 5) {
                Text(k)
                    .font(LogXType.ui(LogXType.caption, .semibold))
                    .foregroundStyle(LogXTheme.muted2)
                Text(v)
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.text2)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .disabled(masked)
        .help(masked ? "\(v) — token yashirilgan" : "\(v) — bosilsa nusxalanadi")
        .accessibilityLabel("\(k) nusxalash")
    }

    private func bodySizeLabel(_ log: NetworkLog) -> String {
        let raw: String
        switch tab {
        case .request: raw = log.requestBody ?? ""
        case .response: raw = log.responseBody ?? ""
        case .headers: raw = JSONFormat.headersText(request: log.requestHeaders, response: log.responseHeaders)
        case .params: raw = JSONFormat.body(for: log, tab: .params)
        }
        return ByteSize.label(raw.utf8.count)
    }
}
