import AppKit
import Combine
import DesignSystem

// MARK: - Custom square checkbox (square bones; ink fill + paper check; rust focus)

final class DSCheckbox: NSControl {
    var isOn = false { didSet { needsDisplay = true } }
    var onToggle: ((Bool) -> Void)?
    private var hovering = false { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        widthAnchor.constraint(equalToConstant: 18).isActive = true
        heightAnchor.constraint(equalToConstant: 18).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("no coder") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                        options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                        owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent)  { hovering = false }
    override func mouseDown(with event: NSEvent) { isOn.toggle(); onToggle?(isOn) }

    override func draw(_ dirtyRect: NSRect) {
        let box = bounds.insetBy(dx: 1, dy: 1)
        if isOn { DSPalette.ink.setFill(); box.fill() }
        (hovering ? DSPalette.accent : DSPalette.borderStrong).setStroke()
        let edge = NSBezierPath(rect: box); edge.lineWidth = hovering ? 2 : 1; edge.stroke()
        if isOn {
            DSPalette.primaryLabel.setStroke()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: box.minX + 4, y: box.midY))
            check.line(to: NSPoint(x: box.midX - 1, y: box.maxY - 5))
            check.line(to: NSPoint(x: box.maxX - 3, y: box.minY + 4))
            check.lineWidth = 2; check.lineCapStyle = .round; check.stroke()
        }
    }
}

// MARK: - Settings

final class SettingsViewController: NSViewController {
    private let model: SettingsModel
    private var bag = Set<AnyCancellable>()
    private lazy var recorder = ShortcutRecorderView(model: model)
    private let loginCheck = DSCheckbox()
    private let loginNote = NSTextField(labelWithString: "")

    private let presets: [(String, HotKeySpec)] = [
        ("⌘⇧C", HotKeySpec(key: .c, modifiers: [.command, .shift])),
        ("⌘⇧V", HotKeySpec(key: .v, modifiers: [.command, .shift])),
        ("⌘⌥V", HotKeySpec(key: .v, modifiers: [.command, .option])),
        ("⌃⇧Space", HotKeySpec(key: .space, modifiers: [.control, .shift]))
    ]

    init(model: SettingsModel) { self.model = model; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("no coder") }

    override func loadView() {
        let root = DSBackgroundView(); root.fill = DSPalette.surfaceWindow
        view = root
        build()
        bind()
    }

    private func heading(_ s: String) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.font = .dsSans(DSType.Size.lg, .semibold); t.textColor = DSPalette.text1
        return t
    }
    private func subhead(_ s: String) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.font = .dsSans(DSType.Size.sm, .medium); t.textColor = DSPalette.text3
        return t
    }
    private func caption(_ s: String) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: s)
        t.font = .dsSans(DSType.Size.sm); t.textColor = DSPalette.text3
        return t
    }

    private func build() {
        let presetRow = NSStackView()
        presetRow.spacing = DSSpacing.s2
        for (label, spec) in presets {
            let b = NSButton(title: label, target: self, action: #selector(pickPreset(_:)))
            b.bezelStyle = .rounded
            b.font = .dsSans(DSType.Size.sm, .medium)
            b.contentTintColor = DSPalette.ink
            b.tag = presets.firstIndex(where: { $0.0 == label }) ?? 0
            presetRow.addArrangedSubview(b)
        }

        let loginRow = NSStackView(views: [loginCheck,
            { let t = NSTextField(labelWithString: "Open at Login")
              t.font = .dsSans(DSType.Size.base); t.textColor = DSPalette.text1; return t }()])
        loginRow.spacing = DSSpacing.s2
        loginRow.alignment = .centerY
        loginCheck.onToggle = { [weak self] on in self?.model.openAtLogin = on }

        loginNote.font = .dsSans(DSType.Size.sm); loginNote.textColor = DSPalette.text3

        let stack = NSStackView(views: [
            heading("Toggle Shortcut"),
            subhead("Recorder"), recorder,
            caption("Click the field, then press the combination you want · Esc to cancel."),
            subhead("Presets"), presetRow,
            Theme.hairline(),
            loginRow, loginNote
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = DSSpacing.s3
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: DSSpacing.s6),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DSSpacing.s6),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DSSpacing.s6),
            recorder.widthAnchor.constraint(equalTo: stack.widthAnchor),
            view.widthAnchor.constraint(equalToConstant: 460),
            view.heightAnchor.constraint(equalToConstant: 340)
        ])
    }

    @objc private func pickPreset(_ sender: NSButton) { model.set(presets[sender.tag].1) }

    private func bind() {
        model.$openAtLogin.sink { [weak self] on in self?.loginCheck.isOn = on }.store(in: &bag)
        model.$loginStatusNote.sink { [weak self] note in
            self?.loginNote.stringValue = note ?? ""
            self?.loginNote.isHidden = (note == nil)
        }.store(in: &bag)
    }
}
