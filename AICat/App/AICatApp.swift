import SwiftUI

@main
struct AICatApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                // One bright look for the whole game (Info.plist opts out of Dark Mode too): the boards,
                // cards and rules are designed on white, and children should see the same colours as the
                // adults helping them.
                .preferredColorScheme(.light)
        }
    }
}
