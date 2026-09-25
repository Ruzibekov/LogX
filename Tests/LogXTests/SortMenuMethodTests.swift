import XCTest
import SwiftUI
import AppKit
@testable import LogX

@MainActor
final class SortMenuMethodTests: XCTestCase {
    private func popup(in view: NSView) -> NSPopUpButton? {
        if let pop = view as? NSPopUpButton { return pop }
        for sub in view.subviews { if let pop = popup(in: sub) { return pop } }
        return nil
    }

    private func openedItems(sortField: LogSortField) throws -> [(title: String, state: NSControl.StateValue, image: NSImage?)] {
        let store = LogStore()
        store.sortField = sortField
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1500, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = NSHostingView(rootView: RequestFilterBar().environmentObject(store))
        window.contentView = host
        window.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let pop = try XCTUnwrap(popup(in: host))
        let menu = try XCTUnwrap(pop.menu)
        var captured: [(String, NSControl.StateValue, NSImage?)] = []
        let timer = Timer(timeInterval: 0.15, repeats: false) { _ in
            MainActor.assumeIsolated {
                captured = menu.items.filter { !$0.title.isEmpty }.map { ($0.title, $0.state, $0.image) }
                menu.cancelTracking()
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        pop.performClick(nil)
        return captured.map { (title: $0.0, state: $0.1, image: $0.2) }
    }

    func testMethodSortItemShowsColoredSwatchInNativeMenu() throws {
        let items = try openedItems(sortField: .time)
        let method = try XCTUnwrap(items.first { $0.title.hasPrefix("Metod") })
        let image = try XCTUnwrap(method.image, "Metod bandida rangli belgi yo'q")
        XCTAssertFalse(image.isTemplate, "menyu rasmni bir rangga bo'yab yubormasligi kerak")
        XCTAssertEqual(method.state, .off)
        XCTAssertEqual(items.filter { $0.image != nil }.count, 1)
    }

    func testActiveSortShowsNativeCheckmarkAndDirection() throws {
        let items = try openedItems(sortField: .method)
        let method = try XCTUnwrap(items.first { $0.title.hasPrefix("Metod") })
        XCTAssertEqual(method.state, .on)
        XCTAssertTrue(method.title.hasSuffix("↓") || method.title.hasSuffix("↑"), method.title)
        XCTAssertNotNil(method.image)
        XCTAssertEqual(items.filter { $0.state == .on }.count, 1)
    }
}
