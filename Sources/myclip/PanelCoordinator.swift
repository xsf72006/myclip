import Foundation

@MainActor
final class PanelCoordinator: ObservableObject {
    static let defaultVisible = 10

    @Published var query: String = ""
    @Published var selection: ClipItem.ID?
    /// Set only by keyboard navigation so the list can scroll the focused row
    /// into view. Hover leaves this nil on purpose — otherwise the list would
    /// jump around as the cursor sweeps across rows.
    @Published var scrollTarget: ClipItem.ID?
    /// When true (and no search query), the list shows all stored items
    /// instead of the first `defaultVisible`. Reset to false on every show.
    @Published var showAll: Bool = false
    /// Increments every time the panel is shown; ClipPanelViewController
    /// observes this (via Combine) to re-focus the search field on each show,
    /// since the panel is reused — not recreated — between shows.
    @Published var focusToken: Int = 0

    /// False until the mouse actually moves after a show. Hover-to-select is
    /// gated on this so the first row stays selected on open even when the
    /// cursor happens to sit over the list. Deliberately NOT @Published —
    /// it's flipped on every mouse-moved event and read imperatively in the
    /// table's mouseEntered, so publishing it would fire needlessly per move.
    var hoverArmed: Bool = false

    /// Items after search filter is applied but before the visibility cap.
    func matchedItems(from items: [ClipItem]) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { ($0.text ?? "").lowercased().contains(q) }
    }

    /// What the panel should actually render: matched items, capped at
    /// `defaultVisible` when no query is active and the user hasn't asked to
    /// expand.
    func visibleItems(from items: [ClipItem]) -> [ClipItem] {
        let matched = matchedItems(from: items)
        if !query.isEmpty || showAll { return matched }
        return Array(matched.prefix(Self.defaultVisible))
    }

    func canExpand(in items: [ClipItem]) -> Bool {
        query.isEmpty && !showAll && matchedItems(from: items).count > Self.defaultVisible
    }

    func moveSelection(in items: [ClipItem], delta: Int) {
        let visible = visibleItems(from: items)
        guard !visible.isEmpty else { selection = nil; return }
        let idx = visible.firstIndex(where: { $0.id == selection }) ?? 0
        let next = max(0, min(visible.count - 1, idx + delta))
        selection = visible[next].id
        scrollTarget = visible[next].id
    }

    func ensureValidSelection(in items: [ClipItem]) {
        let visible = visibleItems(from: items)
        if selection == nil || !visible.contains(where: { $0.id == selection }) {
            selection = visible.first?.id
        }
    }
}
