import AppKit

// We don't use SwiftUI's App protocol — the empty Settings scene was
// auto-shown on first launch under `.accessory` activation. Run a plain
// AppKit loop instead; AppDelegate is the canonical entry point.
//
// AppDelegate is @MainActor; main.swift top-level is non-isolated. wrap
// the wiring in MainActor.assumeIsolated to satisfy strict concurrency
// — we know we're on main here, by definition of main.swift.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
