import SwiftUI

struct PayphoneIllustration: View {
    var lineColor: Color = BCSColor.ink.opacity(0.7)
    var lineWidth: CGFloat = 1.25

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 180, size.height / 220)
            context.scaleBy(x: scale, y: scale)

            var body = Path(roundedRect: CGRect(x: 54, y: 18, width: 88, height: 178), cornerRadius: 8)
            body.addRoundedRect(in: CGRect(x: 72, y: 39, width: 52, height: 38), cornerSize: CGSize(width: 4, height: 4))
            body.addRoundedRect(in: CGRect(x: 74, y: 140, width: 48, height: 27), cornerSize: CGSize(width: 4, height: 4))
            context.stroke(body, with: .color(lineColor), lineWidth: lineWidth)

            var receiver = Path()
            receiver.move(to: CGPoint(x: 42, y: 42))
            receiver.addCurve(to: CGPoint(x: 38, y: 157), control1: CGPoint(x: 25, y: 68), control2: CGPoint(x: 26, y: 130))
            receiver.addCurve(to: CGPoint(x: 55, y: 174), control1: CGPoint(x: 40, y: 169), control2: CGPoint(x: 47, y: 175))
            receiver.addLine(to: CGPoint(x: 67, y: 158))
            receiver.addCurve(to: CGPoint(x: 59, y: 143), control1: CGPoint(x: 64, y: 151), control2: CGPoint(x: 62, y: 146))
            receiver.addCurve(to: CGPoint(x: 58, y: 60), control1: CGPoint(x: 48, y: 118), control2: CGPoint(x: 48, y: 82))
            receiver.addCurve(to: CGPoint(x: 67, y: 45), control1: CGPoint(x: 62, y: 52), control2: CGPoint(x: 64, y: 48))
            receiver.addLine(to: CGPoint(x: 55, y: 30))
            receiver.addCurve(to: CGPoint(x: 42, y: 42), control1: CGPoint(x: 48, y: 32), control2: CGPoint(x: 44, y: 36))
            context.stroke(receiver, with: .color(lineColor), lineWidth: lineWidth)

            for row in 0..<4 {
                for column in 0..<3 {
                    let rect = CGRect(x: 78 + CGFloat(column) * 14, y: 86 + CGFloat(row) * 13, width: 5, height: 5)
                    context.stroke(Path(ellipseIn: rect), with: .color(lineColor), lineWidth: lineWidth)
                }
            }

            var cord = Path()
            cord.move(to: CGPoint(x: 53, y: 174))
            cord.addCurve(to: CGPoint(x: 33, y: 213), control1: CGPoint(x: 52, y: 198), control2: CGPoint(x: 24, y: 194))
            cord.addCurve(to: CGPoint(x: 86, y: 211), control1: CGPoint(x: 43, y: 231), control2: CGPoint(x: 74, y: 224))
            context.stroke(cord, with: .color(lineColor), lineWidth: lineWidth)
        }
        .aspectRatio(180 / 220, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct SaulPhoneTile: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BCSColor.yellow)
            Image(systemName: "phone.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BCSColor.ink)
        }
        .frame(width: 52, height: 52)
        .accessibilityLabel("Позвонить")
    }
}
