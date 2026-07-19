import SwiftUI

@main
struct BetterCallSaulApp: App {
    @State private var router = AppRouter()
    @State private var workflow: CaseWorkflowStore
    private let problemClassifier: any ProblemClassifying

    init() {
        let services: AIServiceContainer
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            services = ProcessInfo.processInfo.arguments.contains("-saul-clarification-testing")
                ? .uiTestingWithClarification
                : .uiTesting
        } else {
            services = .bundled()
        }
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
