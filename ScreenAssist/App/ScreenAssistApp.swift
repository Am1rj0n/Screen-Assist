import SwiftUI

@main
struct ScreenAssistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — this is a floating overlay app
        // Settings window is accessible from the panel itself
        Settings {
            SettingsView()
        }
    }
}
