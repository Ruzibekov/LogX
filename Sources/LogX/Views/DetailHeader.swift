import AppKit
import SwiftUI
import LogXCore

struct DetailHeader: View {
    @EnvironmentObject private var store: LogStore
    var log: NetworkLog
    var tab: DetailTab
    @State private var urlCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(log.method)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(LogXTheme.methodColor(log.method))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LogXTheme.methodColor(log.method).opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(LogXTheme.methodColor(log.method).opacity(0.35), lineWidth: 1)
                    )

                HStack(spacing: 5) {
                    Circle()
                        .fill(LogXTheme.status(log.statusClass))
                        .frame(width: 6, height: 6)
                    Text(log.responseCode.map(String.init) ?? "NET")
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(LogXTheme.status(log.statusClass))
                    Text(log.statusDescription)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LogXTheme.status(log.statusClass).opacity(0.95))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LogXTheme.status(log.statusClass).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(LogXTheme.status(log.statusClass).opacity(0.3), lineWidth: 1)
                )

                if log.durationMs != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9.5))
                        Text(log.formattedDuration)
                    }
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(LogXTheme.line, lineWidth: 1))
                }

                Text(bodySizeLabel(log))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(LogXTheme.line, lineWidth: 1))

                Spacer()

                HeaderIconButton(
                    icon: store.isFavorite(log.key) ? "star.fill" : "star",
                    isHighlighted: store.isFavorite(log.key),
                    highlightColor: LogXTheme.warn,
                    help: "Sevimli"
                ) {
                    store.toggleFavorite(log.key)
                }
            }

            HStack(spacing: 8) {
                Text(store.shareableURL(log))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.text2)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer(minLength: 4)

                Button {
                    CopyBox.plainText(store.shareableURL(log))
                    urlCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { urlCopied = false }
                } label: {
                    Image(systemName: urlCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
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

            HStack(spacing: 6) {
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
                HStack(spacing: 6) {
                    ForEach(identity, id: \.key) { chip in
                        metaChip(chip.key, chip.value)
                    }
                }
            }

            if let msg = problemMessage {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(msg)
                        .font(.system(size: 11.5, weight: .medium))
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
        .padding(12)
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

    private func metaChip(_ k: String, _ v: String) -> some View {
        Button {
            CopyBox.plainText(v)
        } label: {
            HStack(spacing: 4) {
                Text(k)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LogXTheme.muted2)
                Text(v)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(LogXTheme.text2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(LogXTheme.well, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(LogXTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Nusxalash")
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
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isHighlighted ? highlightColor : (hovered ? LogXTheme.text : LogXTheme.muted))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovered ? LogXTheme.panel2 : LogXTheme.well)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isHighlighted ? highlightColor.opacity(0.5) : (hovered ? LogXTheme.accent.opacity(0.4) : LogXTheme.line), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
