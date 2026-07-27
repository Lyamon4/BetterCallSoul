import SwiftUI

@main
struct BetterCallSaulApp: App {
    @State private var router: AppRouter
    @State private var workflow: CaseWorkflowStore
    @State private var profile: UserProfileStore
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
        let profileStorage: UserDefaults
        if scenario == .uiTesting || scenario == .uiTestingWithClarification {
            let suiteName = "BetterCallSaul.UITesting.Profile"
            profileStorage = UserDefaults(suiteName: suiteName)!
            profileStorage.removePersistentDomain(forName: suiteName)
        } else {
            profileStorage = .standard
        }
        _profile = State(initialValue: UserProfileStore(storage: profileStorage))
        problemClassifier = services.problemClassifier
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                router: router,
                workflow: workflow,
                profile: profile,
                problemClassifier: problemClassifier
            )
        }
    }
}
