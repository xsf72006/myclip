import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var coordinator: PanelCoordinator
    let onPaste: (ClipItem) -> Void
    let onCopy:  (ClipItem) -> Void

    @FocusState private var searchFocused: Bool

    var visible: [ClipItem] {
        coordinator.visibleItems(from: store.items)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            HStack(spacing: 0) {
                listColumn.frame(width: 280)
                Divider()
                previewArea
            }
        }
        .frame(minWidth: 600, minHeight: 360)
        .background(VisualEffectBlur())
        .onAppear {
            focusSearchSoon()
            coordinator.ensureValidSelection(in: store.items)
        }
        .onChange(of: coordinator.focusToken) { _, _ in
            focusSearchSoon()
        }
        .onChange(of: coordinator.query) { _, _ in
            coordinator.ensureValidSelection(in: store.items)
        }
        .onChange(of: coordinator.showAll) { _, _ in
            coordinator.ensureValidSelection(in: store.items)
        }
        .onChange(of: store.items) { _, _ in
            coordinator.ensureValidSelection(in: store.items)
        }
    }

    /// SwiftUI sets @FocusState before NSPanel finishes becoming key, so the
    /// focus is silently dropped. A tiny delay sidesteps the race.
    private func focusSearchSoon() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            searchFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
            if !store.items.isEmpty {
                Button(action: confirmAndClear) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all history")
                .accessibilityLabel("Clear all history")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            list
            if coordinator.canExpand(in: store.items) {
                Divider()
                Button {
                    coordinator.showAll = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Show all \(store.items.count) items")
                            .font(.caption)
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                .padding(.vertical, 6)
                .accessibilityLabel("Show all \(store.items.count) items")
            }
        }
    }

    private var list: some View {
        List(selection: $coordinator.selection) {
            ForEach(visible) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.kind == .image ? "photo" : "doc.text")
                        .foregroundStyle(.secondary)
                    Text(item.displayTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .tag(Optional(item.id))
                .contextMenu {
                    Button("Paste into previous app") { onPaste(item) }
                    Button("Copy")                    { onCopy(item) }
                    Divider()
                    Button("Remove", role: .destructive) { store.remove(item) }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay(alignment: .center) {
            if visible.isEmpty {
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

    private func confirmAndClear() {
        let count = store.items.count
        let alert = NSAlert()
        alert.messageText = "Clear all \(count) item\(count == 1 ? "" : "s")?"
        alert.informativeText = "This deletes every entry in myclip history and cannot be undone."
        alert.alertStyle = .warning
        // Cancel first → it's the default (responds to Enter) and sits on the
        // right per macOS HIG. Clear is the explicit destructive choice.
        alert.addButton(withTitle: "Cancel")
        let clearBtn = alert.addButton(withTitle: "Clear")
        clearBtn.hasDestructiveAction = true
        if alert.runModal() == .alertSecondButtonReturn {
            store.clear()
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
