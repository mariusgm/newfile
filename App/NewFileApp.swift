import SwiftUI

@main
struct NewFileApp: App {
    var body: some Scene {
        WindowGroup("NewFile") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
