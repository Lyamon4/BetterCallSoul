import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case home
    case cases
    case tools
    case profile

    var title: String {
        switch self {
        case .home: "Главная"
        case .cases: "Обращения"
        case .tools: "Инструменты"
        case .profile: "Профиль"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .cases: "doc.text.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .profile: "person.crop.circle"
        }
    }
}

enum AppRoute: Hashable {
    case evidence
    case aiAnalysis
    case signature
    case document
    case archivedDocument(UUID)
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var path: [AppRoute] = []

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    func open(_ route: AppRoute) {
        path.append(route)
    }

    func reset() {
        path.removeAll()
    }
}
