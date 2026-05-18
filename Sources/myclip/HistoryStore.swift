import Foundation
import AppKit

@MainActor
final class HistoryStore: ObservableObject {
    static let maxItems = 50

    @Published private(set) var items: [ClipItem] = []

    /// Tracks the NSPasteboard.changeCount of writes we initiated ourselves
    /// (paste-back). ClipboardMonitor consults this to avoid re-adding our
    /// own clipboard writes as new history entries.
    var lastSelfWrittenChangeCount: Int = -1

    private let storeDir: URL
    private let metaFile: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storeDir = support.appendingPathComponent("myclip", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        metaFile = storeDir.appendingPathComponent("history.json")
        load()
    }

    var top: ClipItem? { items.first }

    func add(_ item: ClipItem) {
        items.insert(item, at: 0)
        if items.count > Self.maxItems {
            let dropped = items.suffix(items.count - Self.maxItems)
            for d in dropped { deleteImageFile(d) }
            items = Array(items.prefix(Self.maxItems))
        }
        save()
    }

    /// Promote an existing item to the top of the list (no new entry, no
    /// timestamp change). Used when the user picks from history.
    func moveToTop(_ item: ClipItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }), idx != 0 else { return }
        let element = items.remove(at: idx)
        items.insert(element, at: 0)
        save()
    }

    func remove(_ item: ClipItem) {
        deleteImageFile(item)
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        for i in items { deleteImageFile(i) }
        items.removeAll()
        save()
    }

    func imageURL(for item: ClipItem) -> URL? {
        guard let name = item.imageFilename else { return nil }
        return storeDir.appendingPathComponent(name)
    }

    func saveImage(_ data: Data) throws -> String {
        let name = "img-\(UUID().uuidString).png"
        try data.write(to: storeDir.appendingPathComponent(name))
        return name
    }

    private func deleteImageFile(_ item: ClipItem) {
        if let url = imageURL(for: item) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: metaFile),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: metaFile, options: .atomic)
    }
}
