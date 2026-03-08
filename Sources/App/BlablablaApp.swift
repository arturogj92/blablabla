import SwiftUI

@main
struct BlablablaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Blablabla") {
            MainWindowView(model: appDelegate.model, settings: appDelegate.model.settings)
                .frame(minWidth: 620, minHeight: 720)
        }
        .defaultPosition(.center)
        .defaultSize(width: 720, height: 760)
    }
}
