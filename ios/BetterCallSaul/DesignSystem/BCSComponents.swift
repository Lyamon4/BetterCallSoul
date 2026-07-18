import SwiftUI

struct BCSPrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(.bcsBody(17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .foregroundStyle(Color.white)
            .background(BCSColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(BCSPressButtonStyle())
    }
}

struct BCSPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct BCSStatusBadge: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
            Circle()
                .fill(isActive ? BCSColor.yellow : BCSColor.secondary.opacity(0.55))
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(BCSColor.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(BCSColor.surface.opacity(0.8))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct BCSDivider: View {
    var body: some View {
        Rectangle()
            .fill(BCSColor.divider)
            .frame(height: 1)
    }
}

struct BCSEditorialTitle: View {
    let text: String
    var size: CGFloat = 46

    var body: some View {
        Text(text)
            .font(.bcsEditorial(size))
            .tracking(-1.7)
            .foregroundStyle(BCSColor.ink)
            .minimumScaleFactor(0.72)
            .fixedSize(horizontal: false, vertical: true)
    }
}
