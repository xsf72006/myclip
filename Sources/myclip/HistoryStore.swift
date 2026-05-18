import Foundation
import AppKit

@MainActor
final class HistoryStore: ObservableObject {
    static let maxItems = 50

    @Published private(set) var items: [ClipItem] = []

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
