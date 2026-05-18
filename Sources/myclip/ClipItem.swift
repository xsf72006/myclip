import Foundation

enum ClipKind: String, Codable {
    case text
    case image
}

struct ClipItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let kind: ClipKind
    let createdAt: Date
    let text: String?
    let imageFilename: String?

    static func text(_ s: String) -> ClipItem {
        ClipItem(id: UUID(), kind: .text, createdAt: Date(), text: s, imageFilename: nil)
    }

    static func image(filename: String, title: String) -> ClipItem {
        ClipItem(id: UUID(), kind: .image, createdAt: Date(), text: title, imageFilename: filename)
    }

    var displayTitle: String {
        switch kind {
        case .text:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let oneLine = trimmed.replacingOccurrences(of: "\n", with: " ")
            return oneLine.isEmpty ? "(empty)" : String(oneLine.prefix(120))
        case .image:
            return text ?? "Image"
        }
    }
}
