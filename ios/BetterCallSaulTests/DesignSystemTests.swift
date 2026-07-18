import SwiftUI
import XCTest
@testable import BetterCallSaul

final class DesignSystemTests: XCTestCase {
    func testSpacingScaleMatchesApprovedSystem() {
        XCTAssertEqual(BCSSpacing.xs, 4)
        XCTAssertEqual(BCSSpacing.sm, 8)
        XCTAssertEqual(BCSSpacing.md, 16)
        XCTAssertEqual(BCSSpacing.lg, 24)
        XCTAssertEqual(BCSSpacing.xl, 32)
    }

    func testMotionRespectsReduceMotion() {
        XCTAssertEqual(BCSMotion.entryOffset(reduceMotion: true), 0)
        XCTAssertEqual(BCSMotion.entryOffset(reduceMotion: false), 8)
    }
}
