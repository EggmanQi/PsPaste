import AppKit
@testable import PsPaste

final class MockPasteboardItem: PasteboardItemReading {
    private(set) var types: [NSPasteboard.PasteboardType] = []
    private var strings: [NSPasteboard.PasteboardType: String] = [:]
    private var dataValues: [NSPasteboard.PasteboardType: Data] = [:]

    func setString(_ string: String, forType type: NSPasteboard.PasteboardType) {
        strings[type] = string
        if !types.contains(type) { types.append(type) }
    }

    func setData(_ data: Data, forType type: NSPasteboard.PasteboardType) {
        dataValues[type] = data
        if !types.contains(type) { types.append(type) }
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        dataValues[type]
    }

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        strings[type]
    }
}

final class MockPasteboard: PasteboardReading {
    var changeCount = 0
    var declaredTypes: [NSPasteboard.PasteboardType] = []
    var items: [any PasteboardItemReading] = []

    /// Simulates one external copy: increments changeCount like NSPasteboard does.
    func simulateCopy(declaredTypes: [NSPasteboard.PasteboardType], items: [MockPasteboardItem]) {
        self.declaredTypes = declaredTypes
        self.items = items
        changeCount += 1
    }
}
