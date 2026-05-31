import Foundation
import CoreText

enum Fonts {
    /// Register the bundled brand fonts (Hanken Grotesk, JetBrains Mono) with
    /// Core Text so `NSFont(name:size:)` can resolve them by family. Call once
    /// at launch. Re-registering an already-registered URL is reported by
    /// CTFontManager as a failure but is harmless, so we ignore the result.
    static func registerBundled() {
        var urls: [URL] = []
        if let inFonts = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") {
            urls += inFonts
        }
        if urls.isEmpty,
           let atRoot = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
            urls += atRoot
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
