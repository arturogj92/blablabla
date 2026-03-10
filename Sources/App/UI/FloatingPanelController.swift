import AppKit
import SwiftUI

final class FloatingPanelController {
    private let panel: NSPanel

    init(model: AppModel) {
        let contentView = FloatingPanelView(model: model)
        let hostingController = NSHostingController(rootView: contentView)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
    }

    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            panel.orderFrontRegardless()
            return
        }

        let width = panel.frame.width
        let height = panel.frame.height
        let x = screen.visibleFrame.midX - (width / 2)
        let y = screen.visibleFrame.minY + 12

        panel.alphaValue = 0
        panel.setFrame(NSRect(x: x, y: y - 20, width: width, height: height), display: true)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }
}
