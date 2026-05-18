import Foundation
import AppKit

@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private weak var store: HistoryStore?
    private var timer: Timer?

    init(store: HistoryStore) {
        self.store = store
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer?.invalidate()
        // Manual Timer + .common only; Timer.scheduledTimer would also
        // register in .default, leaving us in two modes redundantly.
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let cc = pasteboard.changeCount
        guard cc != lastChangeCount else { return }
        lastChangeCount = cc
        // Skip writes we made ourselves during paste-back; otherwise picking
        // an item from history would add a duplicate entry.
        if let store, cc == store.lastSelfWrittenChangeCount {
            store.lastSelfWrittenChangeCount = -1
            return
        }
        capture()
    }

    private func capture() {
        guard let store = store else { return }
        let types = Set(pasteboard.types ?? [])

        let text = pasteboard.string(forType: .string)

        var imageData: Data?
        if let png = pasteboard.data(forType: .png) {
            imageData = png
        } else if let tiff = pasteboard.data(forType: .tiff),
                  let rep = NSBitmapImageRep(data: tiff) {
            imageData = rep.representation(using: .png, properties: [:])
        }

        guard ClipboardFilter.shouldAccept(types: types, text: text, image: imageData) else { return }

        // Match the filter's notion of validity (trim-empty for text). If both
        // text and image are present and valid, text wins as the primary rep.
        let candidate: ClipItem
        if ClipboardFilter.hasValidText(text), let text {
            candidate = .text(text)
        } else if ClipboardFilter.hasValidImage(imageData), let imageData {
            do {
                let fname = try store.saveImage(imageData)
                candidate = .image(filename: fname, byteCount: imageData.count)
            } catch {
                return
            }
        } else {
            return
        }

        // Simple dedup: if the same text was just added, skip.
        if let top = store.top,
           top.kind == .text,
           candidate.kind == .text,
           top.text == candidate.text {
            return
        }

        store.add(candidate)
    }
}
