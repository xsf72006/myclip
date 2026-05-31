import AppKit
import Combine
import DesignSystem

// MARK: - Search field container (draws DS focus ring; square; surfaceInput)

final class DSSearchFieldContainer: NSView, NSTextFieldDelegate {
    let field = NSTextField()
    private let magnifier = NSImageView()
    var onChange: ((String) -> Void)?
    private var focused = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        magnifier.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        magnifier.contentTintColor = DSPalette.text3
        magnifier.translatesAutoresizingMaskIntoConstraints = false

        field.placeholderString = "Search clipboard history…"
        field.font = .dsSans(DSType.Size.sm)
        field.textColor = DSPalette.text1
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none           // we draw the DS ring ourselves
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        addSubview(magnifier); addSubview(field)
        NSLayoutConstraint.activate([
            magnifier.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DSSpacing.s3),
            magnifier.centerYAnchor.constraint(equalTo: centerYAnchor),
            magnifier.widthAnchor.constraint(equalToConstant: DSIcon.inline),
            magnifier.heightAnchor.constraint(equalToConstant: DSIcon.inline),
            field.leadingAnchor.constraint(equalTo: magnifier.trailingAnchor, constant: DSSpacing.s2),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DSSpacing.s3),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 34)
        ])
    }
    required init?(coder: NSCoder) { fatalError("no coder") }

    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        DSPalette.surfaceInput.setFill()
        bounds.fill()
        DSPalette.border.setStroke()
        let edge = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        edge.lineWidth = 1; edge.stroke()
        if focused { Theme.drawFocusRing(in: bounds) }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay = true
    }

    func controlTextDidChange(_ obj: Notification) { onChange?(field.stringValue) }
    func controlTextDidBeginEditing(_ obj: Notification) { focused = true; needsDisplay = true }
    func controlTextDidEndEditing(_ obj: Notification) { focused = false; needsDisplay = true }
}

// MARK: - Row view: square ink fill when selected

final class ClipRowView: NSTableRowView {
    var dsSelected = false { didSet { if oldValue != dsSelected { needsDisplay = true } } }

    override func drawBackground(in dirtyRect: NSRect) {
        if dsSelected {
            DSPalette.ink.setFill(); bounds.fill()
        }
    }
    override func drawSelection(in dirtyRect: NSRect) { /* selection drawn in drawBackground */ }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay = true
    }
}

// MARK: - Row cell: icon + title; colors flip to paper when selected

final class ClipRowCellView: NSTableCellView {
    let icon = NSImageView()
    let title = NSTextField(labelWithString: "")
    var itemID: ClipItem.ID?

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .dsSans(DSType.Size.sm)
        title.lineBreakMode = .byTruncatingTail
        title.cell?.usesSingleLineMode = true
        addSubview(icon); addSubview(title)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DSSpacing.s3),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: DSIcon.inline),
            icon.heightAnchor.constraint(equalToConstant: DSIcon.inline),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: DSSpacing.s2),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DSSpacing.s3),
            title.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("no coder") }

    func configure(_ item: ClipItem, selected: Bool) {
        itemID = item.id
        icon.image = NSImage(systemSymbolName: item.kind == .image ? "photo" : "doc.text",
                             accessibilityDescription: nil)
        title.stringValue = item.displayTitle
        let fg = selected ? DSPalette.primaryLabel : DSPalette.text1
        title.textColor = fg
        icon.contentTintColor = selected ? DSPalette.primaryLabel : DSPalette.text3
    }
}

// MARK: - Controller

final class ClipPanelViewController: NSViewController {
    private let store: HistoryStore
    private let coordinator: PanelCoordinator
    private let onPaste: (ClipItem) -> Void
    private let onCopy: (ClipItem) -> Void

    private let search = DSSearchFieldContainer()
    private let clearSearchButton = NSButton()
    private let trashButton = NSButton()
    private let tableView = NSTableView()
    private let tableScroll = NSScrollView()
    private let showAllButton = NSButton()
    private let emptyLabel = NSTextField(labelWithString: "")
    private lazy var preview = PreviewPaneView(store: store)

    private var bag = Set<AnyCancellable>()
    private var rows: [ClipItem] = []

    init(store: HistoryStore, coordinator: PanelCoordinator,
         onPaste: @escaping (ClipItem) -> Void, onCopy: @escaping (ClipItem) -> Void) {
        self.store = store; self.coordinator = coordinator
        self.onPaste = onPaste; self.onCopy = onCopy
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("no coder") }

    override func loadView() {
        let root = DSBackgroundView()
        root.fill = DSPalette.surfaceWindow
        view = root
        view.translatesAutoresizingMaskIntoConstraints = false
        buildLayout()
        wireBindings()
    }

    private func buildLayout() {
        search.translatesAutoresizingMaskIntoConstraints = false
        search.onChange = { [weak self] q in self?.coordinator.query = q }

        configureGlyphButton(clearSearchButton, symbol: "xmark.circle.fill",
                             tip: "Clear search", action: #selector(clearSearch))
        configureGlyphButton(trashButton, symbol: "trash",
                             tip: "Clear all history", action: #selector(confirmAndClear))

        let searchRow = NSStackView(views: [search, clearSearchButton, trashButton])
        searchRow.orientation = .horizontal
        searchRow.spacing = DSSpacing.s2
        searchRow.translatesAutoresizingMaskIntoConstraints = false
        search.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let topRule = Theme.hairline()
        let midRule = Theme.hairline(vertical: true)

        let col = NSTableColumn(identifier: .init("clip"))
        col.resizingMask = .autoresizingMask
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = 28
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.menu = makeRowMenu()
        tableScroll.documentView = tableView
        tableScroll.drawsBackground = false
        tableScroll.hasVerticalScroller = true
        tableScroll.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = .dsSans(DSType.Size.sm)
        emptyLabel.textColor = DSPalette.text3
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        showAllButton.bezelStyle = .inline
        showAllButton.isBordered = false
        showAllButton.target = self
        showAllButton.action = #selector(showAll)
        showAllButton.translatesAutoresizingMaskIntoConstraints = false
        showAllButton.isHidden = true

        let listColumn = NSView()
        listColumn.translatesAutoresizingMaskIntoConstraints = false
        listColumn.addSubview(tableScroll); listColumn.addSubview(emptyLabel); listColumn.addSubview(showAllButton)
        NSLayoutConstraint.activate([
            tableScroll.topAnchor.constraint(equalTo: listColumn.topAnchor),
            tableScroll.leadingAnchor.constraint(equalTo: listColumn.leadingAnchor),
            tableScroll.trailingAnchor.constraint(equalTo: listColumn.trailingAnchor),
            tableScroll.bottomAnchor.constraint(equalTo: showAllButton.topAnchor),
            showAllButton.leadingAnchor.constraint(equalTo: listColumn.leadingAnchor),
            showAllButton.trailingAnchor.constraint(equalTo: listColumn.trailingAnchor),
            showAllButton.bottomAnchor.constraint(equalTo: listColumn.bottomAnchor),
            showAllButton.heightAnchor.constraint(equalToConstant: 26),
            emptyLabel.centerXAnchor.constraint(equalTo: tableScroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableScroll.centerYAnchor)
        ])

        preview.translatesAutoresizingMaskIntoConstraints = false
        for v in [searchRow, topRule, listColumn, midRule, preview] { view.addSubview(v) }
        let p = DSSpacing.s3
        NSLayoutConstraint.activate([
            searchRow.topAnchor.constraint(equalTo: view.topAnchor, constant: DSSpacing.s2),
            searchRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: p),
            searchRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -p),
            topRule.topAnchor.constraint(equalTo: searchRow.bottomAnchor, constant: DSSpacing.s2),
            topRule.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topRule.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listColumn.topAnchor.constraint(equalTo: topRule.bottomAnchor),
            listColumn.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listColumn.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            listColumn.widthAnchor.constraint(equalToConstant: 280),
            midRule.topAnchor.constraint(equalTo: topRule.bottomAnchor),
            midRule.leadingAnchor.constraint(equalTo: listColumn.trailingAnchor),
            midRule.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            preview.topAnchor.constraint(equalTo: topRule.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: midRule.trailingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 600),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 360)
        ])
    }

    private func configureGlyphButton(_ b: NSButton, symbol: String, tip: String, action: Selector) {
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        b.contentTintColor = DSPalette.text3
        b.isBordered = false
        b.bezelStyle = .inline
        b.imagePosition = .imageOnly
        b.toolTip = tip
        b.target = self
        b.action = action
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func makeRowMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(NSMenuItem(title: "Paste into previous app", action: #selector(menuPaste), keyEquivalent: ""))
        m.addItem(NSMenuItem(title: "Copy", action: #selector(menuCopy), keyEquivalent: ""))
        m.addItem(.separator())
        m.addItem(NSMenuItem(title: "Remove", action: #selector(menuRemove), keyEquivalent: ""))
        m.items.forEach { $0.target = self }
        return m
    }

    private func wireBindings() {
        store.$items
            .combineLatest(coordinator.$query, coordinator.$showAll)
            .sink { [weak self] _, _, _ in self?.reload() }
            .store(in: &bag)
        coordinator.$selection
            .sink { [weak self] sel in self?.applySelection(sel) }
            .store(in: &bag)
        coordinator.$scrollTarget
            .compactMap { $0 }
            .sink { [weak self] id in self?.scrollTo(id) }
            .store(in: &bag)
        coordinator.$focusToken
            .sink { [weak self] _ in self?.focusSearch() }
            .store(in: &bag)
    }

    private func reload() {
        rows = coordinator.visibleItems(from: store.items)
        tableView.reloadData()
        clearSearchButton.isHidden = coordinator.query.isEmpty
        trashButton.isHidden = store.items.isEmpty
        emptyLabel.isHidden = !rows.isEmpty
        emptyLabel.stringValue = coordinator.query.isEmpty ? "No history yet" : "No matches"
        let canExpand = coordinator.canExpand(in: store.items)
        showAllButton.isHidden = !canExpand
        if canExpand {
            showAllButton.attributedTitle = NSAttributedString(
                string: "Show all \(store.items.count) items",
                attributes: [.font: NSFont.dsSans(DSType.Size.xs, .medium),
                             .foregroundColor: DSPalette.text2])
        }
        applySelection(coordinator.selection)
    }

    private func applySelection(_ sel: ClipItem.ID?) {
        for r in 0..<rows.count {
            guard let rv = tableView.rowView(atRow: r, makeIfNecessary: false) as? ClipRowView,
                  let cv = tableView.view(atColumn: 0, row: r, makeIfNecessary: false) as? ClipRowCellView
            else { continue }
            let isSel = rows[r].id == sel
            rv.dsSelected = isSel
            cv.configure(rows[r], selected: isSel)
        }
        preview.show(rows.first(where: { $0.id == sel }))
    }

    private func scrollTo(_ id: ClipItem.ID) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        tableView.scrollRowToVisible(idx)
    }

    private func focusSearch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self.search.field)
        }
    }

    @objc private func clearSearch() { coordinator.query = ""; search.field.stringValue = "" }
    @objc private func showAll() { coordinator.showAll = true }
    @objc private func rowClicked() {
        let r = tableView.clickedRow
        guard rows.indices.contains(r) else { return }
        onPaste(rows[r])
    }
    private func contextItem() -> ClipItem? {
        let r = tableView.clickedRow
        return rows.indices.contains(r) ? rows[r] : nil
    }
    @objc private func menuPaste()  { if let i = contextItem() { onPaste(i) } }
    @objc private func menuCopy()   { if let i = contextItem() { onCopy(i) } }
    @objc private func menuRemove() { if let i = contextItem() { store.remove(i) } }

    @objc private func confirmAndClear() {
        let count = store.items.count
        let alert = NSAlert()
        alert.messageText = "Clear all \(count) item\(count == 1 ? "" : "s")?"
        alert.informativeText = "This deletes every entry in myclip history and cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        let clearBtn = alert.addButton(withTitle: "Clear")
        clearBtn.hasDestructiveAction = true
        if alert.runModal() == .alertSecondButtonReturn { store.clear() }
    }
}

extension ClipPanelViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rv = (tableView.makeView(withIdentifier: .init("ClipRowView"), owner: self) as? ClipRowView) ?? ClipRowView()
        rv.identifier = .init("ClipRowView")
        rv.dsSelected = rows[row].id == coordinator.selection
        return rv
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = (tableView.makeView(withIdentifier: .init("ClipRowCellView"), owner: self) as? ClipRowCellView) ?? ClipRowCellView()
        cell.identifier = .init("ClipRowCellView")
        cell.configure(rows[row], selected: rows[row].id == coordinator.selection)
        return cell
    }

    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        // A per-row tracking area gives us mouseEntered. We do NOT bake the row
        // index in: it goes stale after reloadData()/row reuse and would select
        // the wrong clip. mouseEntered recomputes the row from the cursor.
        rowView.trackingAreas.forEach { rowView.removeTrackingArea($0) }
        let ta = NSTrackingArea(rect: rowView.bounds,
                                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                owner: self,
                                userInfo: nil)
        rowView.addTrackingArea(ta)
    }
}

extension ClipPanelViewController {
    override func mouseEntered(with event: NSEvent) {
        guard coordinator.hoverArmed else { return }
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        guard rows.indices.contains(row) else { return }
        coordinator.selection = rows[row].id
    }
}
