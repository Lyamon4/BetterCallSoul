import CoreGraphics
import XCTest
@testable import BetterCallSaul

final class HandwrittenSignatureTests: XCTestCase {
    func testSinglePointStrokeDoesNotCountAsSignature() {
        let signature = HandwrittenSignature(
            strokes: [[CGPoint(x: 0.4, y: 0.5)]]
        )

        XCTAssertTrue(signature.isEmpty)
    }

    func testSignatureClampsNormalizedCoordinatesAndScalesIntoTargetSize() {
        let signature = HandwrittenSignature(
            strokes: [[
                CGPoint(x: -0.5, y: 0.25),
                CGPoint(x: 1.4, y: 0.75)
            ]]
        )

        XCTAssertEqual(
            signature.points(in: CGSize(width: 200, height: 80)),
            [[CGPoint(x: 0, y: 20), CGPoint(x: 200, y: 60)]]
        )
    }

    func testTwoDistinctPointsCreateSignature() {
        let signature = HandwrittenSignature(
            strokes: [[
                CGPoint(x: 0.1, y: 0.2),
                CGPoint(x: 0.8, y: 0.7)
            ]]
        )

        XCTAssertFalse(signature.isEmpty)
        XCTAssertEqual(signature.strokes.count, 1)
    }
}
