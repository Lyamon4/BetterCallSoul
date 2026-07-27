import SwiftUI

struct DocumentSignatureView: View {
    let signature: HandwrittenSignature
    var lineWidth: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            for points in signature.points(in: size) where points.count > 1 {
                var path = Path()
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(
                    path,
                    with: .color(BCSColor.ink),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Рукописная подпись добавлена")
    }
}
