import AppKit
import DesignSystem

final class PreviewPaneView: NSView {
    private let store: HistoryStore

    private let kindLabel = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private let scroll = NSScrollView()
    private let textView = NSTextView()
    private let imageView = NSImageView()
    private let emptyLabel = NSTextField(labelWithString: "No selection")
    /// The text body currently shown (nil for image/empty). Kept so we can
    /// re-render with a freshly resolved color when the appearance flips.
    private var shownText: String?

    init(store: HistoryStore) {
        self.store = store
        super.init(frame: .zero)
        wantsLayer = true
        buildLayout()
    }
    required init?(coder: NSCoder) { fatalError("no coder") }

    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        DSPalette.surface.setFill()
        bounds.fill()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay = true
        // Re-resolve the body text color for the new appearance (it's baked
        // into the attributed string, so it doesn't auto-flip like a label's).
        if let shownText { applyText(shownText) }
    }

    private func buildLayout() {
        for l in [kindLabel, dateLabel] {
            l.font = .dsMono(DSType.Size.xs, .medium)
            l.textColor = DSPalette.text3
            l.translatesAutoresizingMaskIntoConstraints = false
        }
        kindLabel.alignment = .left
        dateLabel.alignment = .right

        let header = NSStackView(views: [kindLabel, dateLabel])
        header.orientation = .horizontal
        header.distribution = .fill
        header.translatesAutoresizingMaskIntoConstraints = false
        kindLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let rule = Theme.hairline()

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .dsMono(DSType.Size.sm)
        textView.textColor = DSPalette.text1
        textView.textContainerInset = NSSize(width: 0, height: 4)
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        // Never let a large image's intrinsic (pixel) size drive the pane/window:
        // lowest hug/compression priority so it only ever scales within the pane.
        imageView.setContentHuggingPriority(.init(1), for: .horizontal)
        imageView.setContentHuggingPriority(.init(1), for: .vertical)
        imageView.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        imageView.setContentCompressionResistancePriority(.init(1), for: .vertical)

        emptyLabel.font = .dsSans(DSType.Size.sm)
        emptyLabel.textColor = DSPalette.text3
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true

        for v in [header, rule, scroll, imageView, emptyLabel] { addSubview(v) }
        let p = DSSpacing.s3
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: p),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: p),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -p),
            rule.topAnchor.constraint(equalTo: header.bottomAnchor, constant: DSSpacing.s2),
            rule.leadingAnchor.constraint(equalTo: leadingAnchor, constant: p),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -p),
            scroll.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: DSSpacing.s2),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: p),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -p),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -p),
            imageView.topAnchor.constraint(equalTo: scroll.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    /// Render `item`, or the empty state when nil.
    func show(_ item: ClipItem?) {
        guard let item else {
            kindLabel.stringValue = ""; dateLabel.stringValue = ""
            shownText = nil
            scroll.isHidden = true; imageView.isHidden = true; emptyLabel.isHidden = false
            return
        }
        emptyLabel.isHidden = true
        kindLabel.stringValue = (item.kind == .image ? "IMAGE" : "TEXT")
        dateLabel.stringValue = item.createdAt.formatted(date: .abbreviated, time: .shortened)
        switch item.kind {
        case .text:
            scroll.isHidden = false; imageView.isHidden = true
            applyText(item.text ?? "")
        case .image:
            shownText = nil
            scroll.isHidden = true; imageView.isHidden = false
            imageView.image = store.image(for: item)
        }
    }

    /// Set the body text as an explicit attributed string. Relying on
    /// `textView.string` + the property-set `font`/`textColor` is fragile:
    /// on some AppKit builds (older SDK link) the text view doesn't apply
    /// those to text set via `.string`, and a *nameless* dynamic `NSColor`
    /// isn't resolved in that path — so the body rendered invisibly while
    /// NSTextField labels (same tokens) were fine. Attributing every glyph
    /// with the font and a color resolved for the current appearance is
    /// build-independent.
    private func applyText(_ s: String) {
        shownText = s
        var color = DSPalette.text1
        effectiveAppearance.performAsCurrentDrawingAppearance {
            color = DSPalette.text1.usingColorSpace(.sRGB) ?? DSPalette.text1
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.dsMono(DSType.Size.sm),
            .foregroundColor: color,
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: s, attributes: attrs))
    }
}
