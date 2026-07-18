import SwiftUI

struct ToolsView: View {
    let items: [ToolItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BetterCallSaul")
                            .font(.bcsBody(15, weight: .bold))
                        Text("Юридический ассистент\nдля жизни в Казахстане")
                            .font(.bcsBody(12))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Label("Дела  23", systemImage: "doc.text")
                        Text("BCS-2026-00123")
                    }
                    .font(.bcsMeta(10))
                    .foregroundStyle(BCSColor.secondary)
                }

                BCSEditorialTitle(text: "Инструменты")
                    .padding(.top, 44)
                Text("Не советуем. Делаем.")
                    .font(.bcsEditorial(25))
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 4)

                BCSDivider().padding(.top, 34)

                ForEach(items) { item in
                    HStack(spacing: 16) {
                        Text(String(format: "%02d", item.id))
                            .font(.bcsEditorial(28))
                            .frame(width: 42, alignment: .leading)
                        Text(item.title)
                            .font(.bcsEditorial(20))
                            .minimumScaleFactor(0.75)
                        Spacer()
                        BCSStatusBadge(
                            title: item.capability.rawValue,
                            isActive: item.capability == .working
                        )
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(BCSColor.ink)
                    .frame(minHeight: 68)
                    BCSDivider()
                }

                HStack(spacing: 20) {
                    PayphoneIllustration(lineColor: BCSColor.ink, lineWidth: 1.2)
                        .frame(width: 72, height: 88)
                    Rectangle()
                        .fill(BCSColor.ink.opacity(0.25))
                        .frame(width: 1, height: 76)
                    Text("Нужен план?\nПозвони Солу.")
                        .font(.bcsEditorial(25))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(20)
                .background(BCSColor.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 104)
        }
        .background(BCSColor.canvas)
    }
}
