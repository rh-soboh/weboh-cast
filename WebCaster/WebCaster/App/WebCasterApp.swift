import SwiftUI

@main
struct WebCasterApp: App {
    init() {
        AdBlockService.shared.compileRules { _ in }
        AdBlockService.shared.updateIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
