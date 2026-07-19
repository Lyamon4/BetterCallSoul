import UIKit
import XCTest
@testable import BetterCallSaul

final class SaulMascotTests: XCTestCase {
    func testEveryStateMapsToExpectedBundledAsset() {
        XCTAssertEqual(
            SaulMascotState.allCases.map(\.assetName),
            ["SaulIdle", "SaulThinking", "SaulTalking", "SaulCelebrating"]
        )

        for state in SaulMascotState.allCases {
            XCTAssertNotNil(UIImage(named: state.assetName), state.assetName)
        }
    }

    func testStaticTipComponentsWereRemovedAfterAssistantLaunch() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("BetterCallSaul/DesignSystem/SaulMascotView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("SaulHelpCopy"))
        XCTAssertFalse(source.contains("SaulTipBubble"))
    }
}
