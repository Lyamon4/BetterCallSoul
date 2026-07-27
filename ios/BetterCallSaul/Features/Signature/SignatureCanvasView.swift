import SwiftUI

struct SignatureCanvasView: View {
    @Binding var signature: HandwrittenSignature
    @State private var activeStroke: [CGPoint] = []

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                draw(signature.points(in: size), in: &context)
                draw(
                    [activeStroke.map {
                        CGPoint(x: $0.x * size.width, y: $0.y * size.height)
                    }],
                    in: &context
                )
            }
            .contentShape(Rectangle())
            .gesture(drawingGesture(size: proxy.size))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Поле для рукописной подписи")
        .accessibilityHint("Проведите пальцем, чтобы оставить подпись")
        .accessibilityIdentifier("signatureCanvas")
    }

    private func drawingGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = normalized(value.location, in: size)
                if activeStroke.last != point {
                    activeStroke.append(point)
                }
            }
            .onEnded { value in
                let point = normalized(value.location, in: size)
                if activeStroke.last != point {
                    activeStroke.append(point)
                }
                signature = HandwrittenSignature(
                    strokes: signature.strokes + [activeStroke]
                )
                activeStroke = []
            }
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(
            x: min(max(point.x / size.width, 0), 1),
            y: min(max(point.y / size.height, 0), 1)
        )
    }

    private func draw(_ strokes: [[CGPoint]], in context: inout GraphicsContext) {
        for points in strokes where points.count > 1 {
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .color(BCSColor.ink),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
