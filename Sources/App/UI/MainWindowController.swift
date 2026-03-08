import AppKit
import SwiftUI

final class MainWindowController: NSWindowController {
    init(model: AppModel) {
        let hostingView = NSHostingView(rootView: MainWindowView(model: model, settings: model.settings))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.title = "Blablabla"
        window.center()
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.moveToActiveSpace]

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showAndFocus() {
        print("DEBUG showAndFocus entered")
        guard let window else { print("DEBUG no window"); return }
        print("DEBUG window frame before=\(window.frame)")

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            if !visibleFrame.intersects(window.frame) {
                window.center()
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.orderFrontRegardless()
        window.makeKey()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
        print("DEBUG window visible=\(window.isVisible) frame after=\(window.frame)")
    }
}
