import SwiftUI

@main
struct BetterCallSaulApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            AppRootView(router: router)
        }
    }
}
