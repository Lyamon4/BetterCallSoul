import Foundation

enum AppLaunchScenario: Equatable {
    case live
    case uiTesting
    case uiTestingWithClarification
    case signaturePreview

    init(arguments: [String]) {
        if arguments.contains("-signature-preview") {
            self = .signaturePreview
        } else if arguments.contains("-saul-clarification-testing") {
            self = .uiTestingWithClarification
        } else if arguments.contains("-ui-testing") {
            self = .uiTesting
        } else {
            self = .live
        }
    }

    var initialPath: [AppRoute] {
        self == .signaturePreview ? [.signature] : []
    }

    var usesBundledServices: Bool {
        self == .live
    }

    var services: AIServiceContainer {
        switch self {
        case .live:
            .bundled()
        case .uiTesting:
            .uiTesting
        case .uiTestingWithClarification:
            .uiTestingWithClarification
        case .signaturePreview:
            .localOnly
        }
    }
}
