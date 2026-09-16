import AppKit
import SwiftUI
import LogXCore

struct DetailHeader: View {
    @EnvironmentObject private var store: LogStore
    var log: NetworkLog
    var tab: DetailTab
    @State private var urlCopied = false
    @AppStorage("logx.detailHeaderCollapsed") private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCollapsed ? 6 : 10) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Text(log.method)
                        .font(LogXType.mono(LogXType.meta, .bold))
                        .foregroundStyle(LogXTheme.methodColor(log.method))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LogXTheme.panel2,
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )

                    HStack(spacing: 6) {
                        Text(log.responseCode.map(String.init) ?? "NET")
                            .font(LogXType.mono(LogXType.meta, .bold))
                            .foregroundStyle(LogXTheme.status(log.statusClass))
                        Text(log.statusDescription)
                            .font(LogXType.ui(LogXType.meta, .semibold))
                            .foregroundStyle(LogXTheme.status(log.statusClass))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LogXTheme.statusTint(log.statusClass),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )

                    if isCollapsed, log.durationMs != nil {
                        Text(log.formattedDuration)
                            .font(LogXType.mono(LogXType.caption))
                            .foregroundStyle(LogXTheme.muted)
                            .chipSurface()
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    HeaderIconButton(
                        icon: store.isFavorite(log.key) ? "star.fill" : "star",
                        isHighlighted: store.isFavorite(log.key),
                        highlightColor: LogXTheme.warn,
                        help: "Sevimli"
                    ) {
                        store.toggleFavorite(log.key)
                    }

                    HeaderIconButton(
                        icon: isCollapsed ? "chevron.down" : "chevron.up",
                        isHighlighted: false,
                        help: isCollapsed ? "Batafsil ma'lumotlarni ko'rsatish" : "Ixcham rejim"
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            isCollapsed.toggle()
                        }
                    }
                }
            }

            if !isCollapsed {
                WrapLayout(spacing: 6, lineSpacing: 6) {
                    if log.durationMs != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9.5, weight: .semibold))
                            Text(log.formattedDuration)
                                .lineLimit(1)
                        }
                        .font(LogXType.mono(LogXType.caption))
                        .foregroundStyle(LogXTheme.muted)
                        .chipSurface()
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    Text(bodySizeLabel(log))
                        .font(LogXType.mono(LogXType.caption))
                        .foregroundStyle(LogXTheme.muted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .chipSurface()
                        .help("Shu tab tanasining hajmi")

                    Text(RelativeTime.stamp(ts: log.ts))
                        .font(LogXType.mono(LogXType.caption))
                        .foregroundStyle(LogXTheme.muted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .chipSurface()
                        .help("So'rov vaqti · \(RelativeTime.label(ts: log.ts))")

                    metaChip("Ilova", log.appLabel)
                    metaChip("Qurilma", deviceLabel)
                    if let env = log.environment, !env.isEmpty {
                        metaChip("Muhit", [env, log.flavor, log.appVersion].compactMap { $0 }.joined(separator: " · "))
                    }
                    if let feature = log.feature, !feature.isEmpty {
                        metaChip("Modul", log.moduleName ?? feature)
                    }
                }

                let identity = identityChips
                if !identity.isEmpty {
                    WrapLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(identity, id: \.key) { chip in
                            metaChip(chip.key, chip.value)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text(URLHighlighter.attributed(store.shareableURL(log), baseFontSize: LogXType.meta))
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .help(store.shareableURL(log))

                Spacer(minLength: 4)

                Button {
                    store.copy(store.shareableURL(log), what: "URL")
                    urlCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { urlCopied = false }
                } label: {
                    Image(systemName: urlCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(urlCopied ? LogXTheme.ok : LogXTheme.muted2)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("URL nusxalash")
                .accessibilityLabel("URL nusxalash")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LogXTheme.well)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(LogXTheme.line, lineWidth: 1)
                    )
            )

            if let msg = problemMessage {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(LogXType.ui(LogXType.meta, .semibold))
                    Text(msg)
                        .font(LogXType.ui(LogXType.body))
                }
                .foregroundStyle(LogXTheme.warn)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LogXTheme.warn.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(LogXTheme.warn.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(14)
        .background(LogXTheme.panel)
    }

    private var deviceLabel: String {
        let label = log.fieldDeviceLabel
        if label != "—" { return label }
        if let serial = log.serial, !serial.isEmpty { return serial }
        return label
    }

    /// PINFL / sessiya / device-id — «Tokenlar» yoqiq bo'lsa qiymat yashiriladi,
    /// chip esa qoladi (mavjudligi ko'rinsin).
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

    /// Ogohlantirish faqat muammo bo'lganda: xato, tarmoq uzilishi yoki 2xx bo'lmagan javob.
    private var problemMessage: String? {
        if let err = log.error, !err.isEmpty { return err }
        guard log.statusClass != .ok2xx, log.statusClass != .redirect3xx else { return nil }
        let msg = log.responseBodyMessage ?? log.responseMessage
        guard let msg, !msg.isEmpty else { return nil }
        if msg.caseInsensitiveCompare(log.statusDescription) == .orderedSame { return nil }
        return msg
    }

    @ViewBuilder
    private func metaChip(_ k: String, _ v: String) -> some View {
        let trimmed = v.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != "—" {
            metaChipBody(k, v)
        }
    }

    private func metaChipBody(_ k: String, _ v: String) -> some View {
        let masked = v.contains("••")
        return Button {
            store.copy(v, what: k)
        } label: {
            HStack(spacing: 4) {
                Text(k)
                    .font(LogXType.ui(LogXType.caption, .semibold))
                    .foregroundStyle(LogXTheme.muted2)
                    .lineLimit(1)
                Text(v)
                    .font(LogXType.mono(LogXType.caption))
                    .foregroundStyle(LogXTheme.text2)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .chipSurface()
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

private struct HeaderIconButton: View {
    var icon: String
    var isHighlighted: Bool = false
    var highlightColor: Color = LogXTheme.ok
    var help: String
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(LogXType.ui(LogXType.body, .semibold))
                .foregroundStyle(isHighlighted ? highlightColor : (hovered ? LogXTheme.text : LogXTheme.muted))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovered ? LogXTheme.panel2 : LogXTheme.well)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isHighlighted ? highlightColor.opacity(0.5) : (hovered ? LogXTheme.chipOnEdge : LogXTheme.line), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}


private extension View {
    func chipSurface() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
