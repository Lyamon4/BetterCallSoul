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

    func testHelpCopyIsDeterministicAndProductSafe() {
        XCTAssertEqual(
            SaulHelpCopy.line(at: 0),
            "Расскажите как было — я помогу собрать главное."
        )
        XCTAssertEqual(SaulHelpCopy.line(at: 3), SaulHelpCopy.line(at: 0))
        XCTAssertFalse(SaulHelpCopy.lines.joined().contains("AI"))
    }
}
