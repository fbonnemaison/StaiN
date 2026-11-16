import SwiftUI

@main
struct StaiNApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        DocumentGroup(newDocument: { ImageDocument() }) { file in
            EditorView(document: file.document)
        }
        .commands { EditorCommands() }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        ClassicSaving.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.applyAppearance()
    }
}
