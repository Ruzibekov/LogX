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
    @State private var headerWidth: CGFloat = 900

    static let labelledActionsMinWidth: CGFloat = 700

    var body: some View {
        VStack(alignment: .leading, spacing: isCollapsed ? 10 : 16) {
            HStack(alignment: .center, spacing: 10) {
                Text(log.method)
                    .font(LogXType.mono(11, .bold))
                    .foregroundStyle(log.method.uppercased() == "DELETE" ? LogXTheme.methodColor(log.method) : LogXTheme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LogXTheme.panel2, in: RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous))
                    .fixedSize()

                Text(URLStyle.attributed(store.shareableURL(log), size: LogXType.title, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(store.shareableURL(log))
                    .frame(minWidth: 80, alignment: .leading)

                copyURLButton

                Spacer(minLength: 10)

                actions
                    .layoutPriority(1)
            }

            DetailStatusHero(
                log: log,
                facts: DetailFacts.make(log: log, sizeLabel: bodySizeLabel(log), collapsed: isCollapsed),
                compact: isCollapsed
            )

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
                        .textSelection(.enabled)
                }
                .foregroundStyle(LogXTheme.warn)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LogXTheme.warn.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(LogXTheme.bg)
        .background(GeometryReader { geo in Color.clear.preference(key: DetailHeaderWidthKey.self, value: geo.size.width) })
        .onPreferenceChange(DetailHeaderWidthKey.self) { width in
            if width > 0, abs(width - headerWidth) > 4 { headerWidth = width }
        }
    }

    private var actions: some View {
        actionRow(labelled: headerWidth >= Self.labelledActionsMinWidth)
    }

    private func actionRow(labelled: Bool) -> some View {
        HStack(spacing: 8) {
            actionPill(
                store.selectedIsReplaying ? "Yuborilmoqda…" : "Qayta yuborish",
                icon: "paperplane",
                kind: .primary,
                labelled: true,
                help: store.replayBlocker(log) ?? "So'rovni Mac'dan qayta yuborish — javob ro'yxatga REPLAY bo'lib tushadi (⌘⏎)"
            ) {
                store.replay(log)
            }
            .disabled(!store.canReplay(log))
            .keyboardShortcut(.return, modifiers: .command)

            actionPill("Farq", icon: "arrow.left.arrow.right", labelled: labelled, help: diffHelp) {
                if let anchor = store.diffAnchor, anchor.key != log.key {
                    store.compareWithAnchor(log)
                } else {
                    store.toggleDiffAnchor(log)
                }
            }

            actionPill("cURL", icon: "terminal", labelled: labelled, help: "cURL buyrug'ini nusxalash (⌘⇧C)") {
                store.copy(CurlBuilder.command(for: log, redact: store.redactEnabled), what: "cURL")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            actionPill("Ulashish", icon: "square.and.arrow.up", labelled: false, help: "Rasm sifatida ulashish") {
                onShare()
            }

            moreMenu
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var moreMenu: some View {
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
                LogXMotion.perform(LogXMotion.snappy) { isCollapsed.toggle() }
            }
        } label: {
            Image(systemName: store.isFavorite(log.key) ? "star.fill" : "ellipsis")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(store.isFavorite(log.key) ? LogXTheme.warn : LogXTheme.text2)
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: LogXRadius.control, style: .continuous)
                        .stroke(LogXTheme.line, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30, height: 30)
        .help("Boshqa amallar")
        .accessibilityLabel("Boshqa amallar")
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
        kind: LogXButtonKind = .outline,
        labelled: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                if labelled {
                    Text(title)
                        .font(LogXType.ui(12.5, kind == .primary ? .semibold : .medium))
                }
            }
        }
        .buttonStyle(LogXButtonStyle(kind: kind, horizontalPadding: labelled ? 11 : 0))
        .help(labelled ? help : "\(title) — \(help)")
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
                .foregroundStyle(urlCopied ? LogXTheme.ok : LogXTheme.muted)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(LogXPressStyle())
        .help("URL nusxalash")
        .accessibilityLabel("URL nusxalash")
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            ForEach(metaFacts, id: \.self) { fact in
                Text(fact)
                    .font(LogXType.mono(LogXType.caption, .medium))
                    .foregroundStyle(LogXTheme.text2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(LogXTheme.panel2, in: RoundedRectangle(cornerRadius: LogXRadius.chip, style: .continuous))
                    .lineLimit(1)
                    .fixedSize()
            }

            Text(scopeLabel)
                .font(LogXType.mono(LogXType.caption))
                .foregroundStyle(LogXTheme.muted)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }

    private var metaFacts: [String] {
        var out: [String] = []
        let repeats = store.repeatCount(for: log)
        if repeats > 1 { out.append("×\(repeats)") }
        if !isCollapsed, let env = log.environment, !env.isEmpty {
            out.append([env, log.flavor, log.appVersion].compactMap { $0 }.joined(separator: " "))
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
                    .foregroundStyle(LogXTheme.muted)
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

struct DetailFact: Hashable {
    let label: String
    let value: String
}

enum DetailFacts {
    static func make(log: NetworkLog, sizeLabel: String, collapsed: Bool) -> [DetailFact] {
        var out: [DetailFact] = []
        if log.durationMs != nil { out.append(DetailFact(label: "Davomiylik", value: log.formattedDuration)) }
        out.append(DetailFact(label: "Hajm", value: sizeLabel))
        out.append(DetailFact(label: "Vaqt", value: RelativeTime.stamp(ts: log.ts)))
        if !collapsed, let module = moduleLabel(log) {
            out.append(DetailFact(label: "Modul", value: module))
        }
        return out
    }

    static func moduleLabel(_ log: NetworkLog) -> String? {
        guard let feature = log.feature, !feature.isEmpty else { return nil }
        return log.moduleName ?? feature
    }

    static func codeLabel(_ log: NetworkLog) -> String {
        log.responseCode.map(String.init) ?? "NET"
    }

    static func reasonIsShort(_ reason: String) -> Bool {
        reason.count <= 16
    }
}

private struct DetailHeaderWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 900
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
