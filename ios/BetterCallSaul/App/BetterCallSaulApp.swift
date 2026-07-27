import SwiftUI

@main
struct BetterCallSaulApp: App {
    @State private var router: AppRouter
    @State private var workflow: CaseWorkflowStore
    private let problemClassifier: any ProblemClassifying

    init() {
        let scenario = AppLaunchScenario(arguments: ProcessInfo.processInfo.arguments)
        let services = scenario.services
        let router = AppRouter()
        router.path = scenario.initialPath
        _router = State(initialValue: router)
        _workflow = State(
            initialValue: CaseWorkflowStore(seed: DemoFixtures.activeCase, services: services)
        )
        problemClassifier = services.problemClassifier
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                router: router,
                workflow: workflow,
                problemClassifier: problemClassifier
            )
        }
    }
}
