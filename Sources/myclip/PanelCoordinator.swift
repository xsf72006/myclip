import Foundation

@MainActor
final class PanelCoordinator: ObservableObject {
    @Published var query: String = ""
    @Published var selection: ClipItem.ID?

    func filteredItems(from items: [ClipItem]) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { ($0.text ?? "").lowercased().contains(q) }
    }

    func moveSelection(in items: [ClipItem], delta: Int) {
        let filtered = filteredItems(from: items)
        guard !filtered.isEmpty else { selection = nil; return }
        let idx = filtered.firstIndex(where: { $0.id == selection }) ?? 0
        let next = max(0, min(filtered.count - 1, idx + delta))
        selection = filtered[next].id
    }

    func ensureValidSelection(in items: [ClipItem]) {
        let filtered = filteredItems(from: items)
        if selection == nil || !filtered.contains(where: { $0.id == selection }) {
            selection = filtered.first?.id
        }
    }
}
