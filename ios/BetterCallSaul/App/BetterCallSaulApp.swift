import SwiftUI

@main
struct BetterCallSaulApp: App {
    @State private var router = AppRouter()
    @State private var workflow: CaseWorkflowStore

    init() {
        let services: AIServiceContainer
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            services = .uiTesting
        } else if let configuration = try? AIConfiguration.bundled() {
            services = .live(configuration: configuration)
        } else {
            services = .localOnly
        }
        _workflow = State(
            initialValue: CaseWorkflowStore(seed: DemoFixtures.activeCase, services: services)
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(router: router, workflow: workflow)
        }
    }
}
