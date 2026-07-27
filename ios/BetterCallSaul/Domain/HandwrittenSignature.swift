import CoreGraphics

struct HandwrittenSignature: Equatable {
    static let empty = HandwrittenSignature(strokes: [])

    let strokes: [[CGPoint]]

    init(strokes: [[CGPoint]]) {
        self.strokes = strokes.compactMap { stroke in
            let normalized = stroke.map { point in
                CGPoint(
                    x: min(max(point.x, 0), 1),
                    y: min(max(point.y, 0), 1)
                )
            }
            guard let first = normalized.first,
                  normalized.contains(where: { $0 != first }) else {
                return nil
            }
            return normalized
        }
    }

    var isEmpty: Bool {
        strokes.isEmpty
    }

    func points(in size: CGSize) -> [[CGPoint]] {
        strokes.map { stroke in
            stroke.map { point in
                CGPoint(x: point.x * size.width, y: point.y * size.height)
            }
        }
    }
}
