import Foundation
import XCTest

final class ProductionSurfaceTests: XCTestCase {
    func testUserFacingSourcesContainNoImplementationOrPrototypeLabels() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceRoot = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("BetterCallSaul")
        let paths = [
            "Features/Home/HomeView.swift",
            "Features/Home/SaulAssistantSheet.swift",
            "Features/Evidence/EvidenceView.swift",
            "Features/AIAnalysis/AIAnalysisView.swift",
            "Features/Profile/ProfileView.swift",
            "Features/Tools/ToolsView.swift"
        ]
        let combined = try paths.map {
            try String(
                contentsOf: sourceRoot.appendingPathComponent($0),
                encoding: .utf8
            )
        }.joined(separator: "\n")

        let forbiddenLabels = [
            "Gemini",
            "DeepSeek",
            "Локальный режим",
            "Продолжаем локально",
            "AI-провайдеры",
            "DEMO",
            "КОНЦЕПТ",
            "SaulPhoneTile",
            "на устройстве"
        ]
        for label in forbiddenLabels {
            XCTAssertFalse(combined.contains(label), "Public surface contains \(label)")
        }
    }
}
