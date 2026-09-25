import AppKit
import CoreText
import SwiftUI

enum LogXFontFamily: String, CaseIterable, Sendable {
    case ui = "Manrope"
    case mono = "Martian Mono"

    var weightRange: ClosedRange<CGFloat> {
        switch self {
        case .ui: return 200...800
        case .mono: return 100...800
        }
    }

    var fixedWidthAxis: CGFloat? {
        switch self {
        case .ui: return nil
        case .mono: return 100
        }
    }
}

enum LogXFonts {
    static let weightAxisTag = 0x7767_6874
    static let widthAxisTag = 0x7764_7468

    private struct CacheKey: Hashable {
        let family: LogXFontFamily
        let size: CGFloat
        let weight: CGFloat
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var availability: [LogXFontFamily: Bool] = [:]
    nonisolated(unsafe) private static var cache: [CacheKey: NSFont] = [:]

    static func axisWeight(_ weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight: return 200
        case .thin: return 100
        case .light: return 300
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        case .heavy, .black: return 800
        default: return 400
        }
    }

    static func clampedWeight(_ weight: Font.Weight, family: LogXFontFamily) -> CGFloat {
        let range = family.weightRange
        return min(max(axisWeight(weight), range.lowerBound), range.upperBound)
    }

    static func variation(family: LogXFontFamily, weight: Font.Weight) -> [Int: CGFloat] {
        var axes = [weightAxisTag: clampedWeight(weight, family: family)]
        if let width = family.fixedWidthAxis { axes[widthAxisTag] = width }
        return axes
    }

    static func isAvailable(_ family: LogXFontFamily) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let known = availability[family] { return known }
        let found = NSFontManager.shared.availableMembers(ofFontFamily: family.rawValue) != nil
        availability[family] = found
        return found
    }

    static func nsFont(_ family: LogXFontFamily, size: CGFloat, weight: Font.Weight) -> NSFont? {
        guard isAvailable(family) else { return nil }
        let key = CacheKey(family: family, size: size, weight: clampedWeight(weight, family: family))
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let axes = variation(family: family, weight: weight).reduce(into: [NSNumber: CGFloat]()) { out, pair in
            out[NSNumber(value: pair.key)] = pair.value
        }
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family.rawValue,
            NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): axes,
        ])
        guard let font = NSFont(descriptor: descriptor, size: size),
              font.familyName == family.rawValue else { return nil }
        lock.lock()
        cache[key] = font
        lock.unlock()
        return font
    }

    @discardableResult
    static func register(directory: URL) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var registered: [String] = []
        for url in files where url.pathExtension.lowercased() == "ttf" {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                registered.append(url.lastPathComponent)
            }
        }
        resetCache()
        URLStyle.clearCache()
        return registered.sorted()
    }

    static func resetCache() {
        lock.lock()
        availability.removeAll()
        cache.removeAll()
        lock.unlock()
    }

    static func systemWeight(_ weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    static func nsMono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> NSFont {
        nsFont(.mono, size: size, weight: weight)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: systemWeight(weight))
    }

    static func nsUI(_ size: CGFloat, _ weight: Font.Weight = .medium) -> NSFont {
        nsFont(.ui, size: size, weight: weight)
            ?? NSFont.systemFont(ofSize: size, weight: systemWeight(weight))
    }
}

enum LogXType {
    static let caption: CGFloat = 10
    static let meta: CGFloat = 12
    static let body: CGFloat = 13
    static let title: CGFloat = 14
    static let display: CGFloat = 22
    static let statusHero: CGFloat = 72

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        if let font = LogXFonts.nsFont(.ui, size: size, weight: weight) { return Font(font as CTFont) }
        return .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if let font = LogXFonts.nsFont(.mono, size: size, weight: weight) { return Font(font as CTFont) }
        return .system(size: size, weight: weight, design: .monospaced)
    }
}
