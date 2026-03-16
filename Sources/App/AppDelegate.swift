import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel

    private var dockTabController: DockTabController!
    private var shortcutMonitor: GlobalShortcutMonitor!
    private var fnKeyMonitor: FnKeyMonitor?
    private var statusItem: NSStatusItem!
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        let settings = SettingsStore()
        self.model = AppModel(
            settings: settings,
            permissions: PermissionManager(),
            transcriptStore: TranscriptStore(),
            insertionService: TextInsertionService(),
            audioCapture: AudioCaptureEngine(),
            streamingClient: AssemblyAIStreamingClient()
        )
        super.init()

        dockTabController = DockTabController(model: model, settings: settings)
        model.showMainWindow = { [weak self] in self?.presentMainWindow() }
        model.showFloatingPanel = { [weak self] in
            guard let self else { return }
            if self.model.settings.showIndicatorOnlyWhenRecording {
                self.dockTabController.show()
            } else {
                self.dockTabController.reposition()
            }
        }
        model.hideFloatingPanel = { [weak self] in
            guard let self else { return }
            if self.model.settings.showIndicatorOnlyWhenRecording {
                self.dockTabController.hide()
            } else {
                self.dockTabController.reposition()
            }
        }

        rebuildShortcutMonitor()
        rebuildFnKeyMonitor()

        settings.$shortcutKeyCode
            .combineLatest(settings.$shortcutModifierFlagsRawValue)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.rebuildShortcutMonitor()
            }
            .store(in: &cancellables)

        settings.$fnKeyEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.rebuildFnKeyMonitor(enabled: enabled)
            }
            .store(in: &cancellables)

        settings.$showIndicatorOnlyWhenRecording
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] onlyWhenRecording in
                guard let self else { return }
                let isRecording = self.model.sessionState != .idle
                if onlyWhenRecording && !isRecording {
                    self.dockTabController.hide()
                } else if !onlyWhenRecording {
                    self.dockTabController.show()
                }
            }
            .store(in: &cancellables)

        // Hide indicator immediately when recording ends (don't wait for delayed callback)
        model.$sessionState
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, self.model.settings.showIndicatorOnlyWhenRecording else { return }
                switch state {
                case .listeningPushToTalk, .listeningLocked:
                    break
                case .idle, .finalizing, .error:
                    self.dockTabController.hide()
                }
            }
            .store(in: &cancellables)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        shortcutMonitor.start()
        fnKeyMonitor?.start()
        model.refreshPermissions()
        if !model.settings.showIndicatorOnlyWhenRecording {
            dockTabController.show()
        }
        presentMainWindow()

        // Delay status item creation so macOS menu bar is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.configureStatusItem()
        }

        model.settings.$hideDockIcon
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyActivationPolicy()
                // Status item can be invalidated by the policy change;
                // re-create it on the next run-loop tick.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.configureStatusItem()
                }
            }
            .store(in: &cancellables)
    }

    private func applyActivationPolicy() {
        NSApp.setActivationPolicy(model.settings.hideDockIcon ? .accessory : .regular)
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutMonitor.stop()
        fnKeyMonitor?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        let image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Blablabla")
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = "B"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Transcripts", action: #selector(showMainWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh Permissions", action: #selector(refreshPermissionsFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Blablabla", action: #selector(quitApplication), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        // Delayed diagnostic to check final window position
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            let frame = self.statusItem.button?.frame ?? .zero
            let vis = self.statusItem.isVisible
            let winFrame = self.statusItem.button?.window?.frame ?? .zero
            let info = "visible=\(vis), buttonFrame=\(frame), windowFrame=\(winFrame)"
            try? info.write(toFile: "/tmp/blablabla-statusitem-debug.txt", atomically: true, encoding: .utf8)
        }
    }

    private func rebuildFnKeyMonitor(enabled: Bool? = nil) {
        fnKeyMonitor?.stop()
        guard enabled ?? model.settings.fnKeyEnabled else {
            fnKeyMonitor = nil
            return
        }
        let monitor = FnKeyMonitor()
        monitor.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.model.handleShortcutPressed()
            }
        }
        monitor.onRelease = { [weak self] in
            Task { @MainActor [weak self] in
                self?.model.handleShortcutReleased()
            }
        }
        fnKeyMonitor = monitor
        if NSApp != nil {
            monitor.start()
        }
    }

    private func rebuildShortcutMonitor() {
        shortcutMonitor?.stop()
        shortcutMonitor = GlobalShortcutMonitor(
            keyCode: model.settings.shortcutKeyCode,
            requiredFlags: model.settings.shortcutModifierFlags
        )
        shortcutMonitor.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.model.handleShortcutPressed()
            }
        }
        shortcutMonitor.onRelease = { [weak self] in
            Task { @MainActor [weak self] in
                self?.model.handleShortcutReleased()
            }
        }

        if NSApp != nil {
            shortcutMonitor.start()
        }
    }

    private func presentMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.collectionBehavior.insert(.moveToActiveSpace)
            if let screen = NSScreen.main ?? NSScreen.screens.first,
               !screen.visibleFrame.intersects(window.frame) {
                window.center()
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showMainWindowFromMenu() {
        presentMainWindow()
    }

    @objc private func refreshPermissionsFromMenu() {
        model.refreshPermissions()
        presentMainWindow()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
