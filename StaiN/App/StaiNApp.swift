import SwiftUI

@main
struct StaiNApp: App {
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
