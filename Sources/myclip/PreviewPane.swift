import SwiftUI
import AppKit

struct PreviewPane: View {
    @ObservedObject var store: HistoryStore
    let item: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.kind == .image ? "Image" : "Text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            ScrollView {
                Text(item.text ?? "")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .image:
            if let url = store.imageURL(for: item),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Image not available")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
