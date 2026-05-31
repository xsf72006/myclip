import AppKit
import DesignSystem

// MARK: - Fonts (brand family with system fallback)

extension NSFont {
    /// Hanken Grotesk — UI/body chassis. Falls back to the system font if the
    /// bundled family failed to register, so the app never renders blank.
    static func dsSans(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        dsFamily("Hanken Grotesk", size: size, weight: weight,
                 fallback: .systemFont(ofSize: size, weight: weight))
    }
    /// JetBrains Mono — preview body, timestamps, the shortcut combo, eyebrows.
    static func dsMono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        dsFamily("JetBrains Mono", size: size, weight: weight,
                 fallback: .monospacedSystemFont(ofSize: size, weight: weight))
    }

    private static func dsFamily(_ family: String, size: CGFloat,
                                 weight: NSFont.Weight, fallback: NSFont) -> NSFont {
        guard let base = NSFont(name: family, size: size) else { return fallback }
        // These are variable fonts (wght axis); nudging the symbolic weight
        // trait makes Core Text interpolate along the axis.
        let desc = base.fontDescriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: weight.rawValue]
        ])
        return NSFont(descriptor: desc, size: size) ?? base
    }
}

// MARK: - A view that paints a design-system surface token

/// Flipped, draw-based view that fills itself with a dynamic token color.
/// Drawing (not a cached `cgColor`) is what lets it flip light/Espresso.
final class DSBackgroundView: NSView {
    var fill: NSColor = DSPalette.surfaceWindow { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        bounds.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Hairlines

enum Theme {
    /// A 1px hairline divider in `DSPalette.border`. Square, no shadow.
    static func hairline(vertical: Bool = false) -> NSView {
        let v = DSBackgroundView()
        v.fill = DSPalette.border
        v.translatesAutoresizingMaskIntoConstraints = false
        if vertical {
            v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        } else {
            v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        }
        return v
    }

    /// Draw the DS focus treatment into `rect`: a 2px ink ring with an inset
    /// 2px rust underline. Call from a container's `draw(_:)` when its field is
    /// first responder. Never a glow.
    static func drawFocusRing(in rect: NSRect) {
        DSPalette.ink.setStroke()
        let ring = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
        ring.lineWidth = 2
        ring.stroke()
        DSPalette.accent.setFill()
        NSRect(x: rect.minX, y: rect.maxY - 2, width: rect.width, height: 2).fill()
    }
}
