import Foundation

@MainActor
final class PanelCoordinator: ObservableObject {
    @Published var query: String = ""
    @Published var selection: ClipItem.ID?
    /// Set only by keyboard navigation so the list can scroll the focused row
    /// into view. Hover leaves this nil on purpose — otherwise the list would
    /// jump around as the cursor sweeps across rows.
    @Published var scrollTarget: ClipItem.ID?
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

    /// The whole list the panel renders: every stored item, filtered by the
    /// search query. We show all 50 stored items (no default cap) — the count
    /// is small enough that an NSTableView renders it instantly, and a cap
    /// only created keyboard-nav edge cases.
    ///
    /// `query` is passed in rather than read from `self.query` because callers
    /// driven by the `$query` publisher receive the new value *before* the
    /// stored property updates (Combine publishes in `willSet`); reading
    /// `self.query` there would filter against the previous keystroke.
    func matchedItems(from items: [ClipItem], query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { ($0.text ?? "").lowercased().contains(q) }
    }

    func moveSelection(in items: [ClipItem], delta: Int) {
        // Arrow keys fire after the field editor has settled, so the stored
        // `query` is current here — no publisher-timing hazard.
        let visible = matchedItems(from: items, query: query)
        guard !visible.isEmpty else { selection = nil; return }
        let idx = visible.firstIndex(where: { $0.id == selection }) ?? 0
        let next = max(0, min(visible.count - 1, idx + delta))
        selection = visible[next].id
        scrollTarget = visible[next].id
    }

    func ensureValidSelection(in items: [ClipItem], query: String) {
        let visible = matchedItems(from: items, query: query)
        if selection == nil || !visible.contains(where: { $0.id == selection }) {
            selection = visible.first?.id
        }
    }
}
