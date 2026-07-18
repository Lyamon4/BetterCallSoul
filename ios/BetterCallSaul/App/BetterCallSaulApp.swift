import SwiftUI

@main
struct BetterCallSaulApp: App {
    @State private var router = AppRouter()
    @State private var workflow = CaseWorkflowStore(seed: DemoFixtures.activeCase)

    var body: some Scene {
        WindowGroup {
            AppRootView(router: router, workflow: workflow)
        }
    }
}
