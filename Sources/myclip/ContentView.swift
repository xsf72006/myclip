import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var coordinator: PanelCoordinator
    let onUse: (ClipItem) -> Void

    @FocusState private var searchFocused: Bool

    private static let defaultVisible = 10

    var filtered: [ClipItem] {
        coordinator.filteredItems(from: store.items)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            HStack(spacing: 0) {
                listView.frame(width: 280)
                Divider()
                previewArea
            }
        }
        .frame(minWidth: 600, minHeight: 360)
        .background(VisualEffectBlur())
        .onAppear {
            searchFocused = true
            coordinator.ensureValidSelection(in: store.items)
        }
        .onChange(of: coordinator.query) { _, _ in
            coordinator.ensureValidSelection(in: store.items)
        }
        .onChange(of: store.items) { _, _ in
            coordinator.ensureValidSelection(in: store.items)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history…", text: $coordinator.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
            if !coordinator.query.isEmpty {
                Button { coordinator.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var listView: some View {
        List(selection: $coordinator.selection) {
            ForEach(filtered) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.kind == .image ? "photo" : "doc.text")
                        .foregroundStyle(.secondary)
                    Text(item.displayTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .tag(Optional(item.id))
                .contextMenu {
                    Button("Copy") { onUse(item) }
                    Button("Remove", role: .destructive) { store.remove(item) }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay(alignment: .bottom) {
            if filtered.isEmpty {
                Text(coordinator.query.isEmpty ? "No history yet" : "No matches")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        if let id = coordinator.selection,
           let item = store.items.first(where: { $0.id == id }) {
            PreviewPane(store: store, item: item)
                .padding(12)
        } else {
            Text("No selection")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .menu
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
