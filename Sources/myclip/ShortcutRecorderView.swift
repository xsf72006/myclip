import AppKit
import DesignSystem
import HotKey

/// A "record-the-keys-I-press" field, AppKit edition. Click to arm; press a
/// combo with ≥1 modifier; Esc cancels. Styled with DS tokens: surfaceInput +
/// hairline + square; arming flips border/text to rust.
final class ShortcutRecorderView: NSControl {
    private weak var model: SettingsModel?
    private let label = NSTextField(labelWithString: "")
    private let glyph = NSImageView()
    private var monitor: Any?
    private var recording = false { didSet { refresh(); needsDisplay = true } }

    init(model: SettingsModel) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        label.font = .dsMono(DSType.Size.sm)
        label.translatesAutoresizingMaskIntoConstraints = false
        glyph.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label); addSubview(glyph)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DSSpacing.s3),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyph.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DSSpacing.s3),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyph.widthAnchor.constraint(equalToConstant: DSIcon.inline),
            glyph.heightAnchor.constraint(equalToConstant: DSIcon.inline),
            heightAnchor.constraint(equalToConstant: 34)
        ])
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("no coder") }

    deinit { if let m = monitor { NSEvent.removeMonitor(m) } }

    /// Clicks anywhere on the control (incl. the trailing glyph) toggle recording.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        DSPalette.surfaceInput.setFill(); bounds.fill()
        (recording ? DSPalette.accent : DSPalette.border).setStroke()
        let edge = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        edge.lineWidth = recording ? 2 : 1; edge.stroke()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay = true
    }

    private func refresh() {
        label.stringValue = recording ? "Press shortcut · Esc to cancel"
                                       : (model?.current.description ?? "")
        label.textColor = recording ? DSPalette.accent : DSPalette.text1
        glyph.image = NSImage(systemSymbolName: recording ? "record.circle.fill" : "pencil",
                             accessibilityDescription: nil)
        glyph.contentTintColor = recording ? DSPalette.accent : DSPalette.text3
    }

    override func mouseDown(with event: NSEvent) { recording ? stop() : start() }

    /// Reset to idle and tear down the key monitor (e.g. when Settings closes).
    func cancelRecording() { stop() }

    private func start() {
        guard monitor == nil else { return }
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handle(e)
        }
    }
    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 { stop(); return nil }       // Esc
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !mods.isEmpty, let key = Self.key(from: event) else { NSSound.beep(); return nil }
        model?.set(HotKeySpec(key: key, modifiers: mods))
        stop(); refresh()
        return nil
    }

    /// (Copied unchanged from the old SwiftUI recorder.)
    private static func key(from event: NSEvent) -> Key? {
        if let chars = event.charactersIgnoringModifiers?.lowercased(),
           let first = chars.first, let key = Key(string: String(first)) { return key }
        switch event.keyCode {
        case 49: return .space;  case 36: return .return;  case 48: return .tab
        case 51: return .delete; case 117: return .forwardDelete
        case 122: return .f1; case 120: return .f2; case 99: return .f3; case 118: return .f4
        case 96: return .f5; case 97: return .f6; case 98: return .f7; case 100: return .f8
        case 101: return .f9; case 109: return .f10; case 103: return .f11; case 111: return .f12
        case 126: return .upArrow; case 125: return .downArrow
        case 123: return .leftArrow; case 124: return .rightArrow
        default: return nil
        }
    }
}
