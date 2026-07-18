import SwiftUI

struct HomeView: View {
    let router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                    .padding(.bottom, 16)

                Text("Добрый вечер, Алим")
                    .font(.bcsBody(17))
                    .foregroundStyle(BCSColor.secondary)

                BCSEditorialTitle(text: "Что случилось?")
                    .padding(.top, 8)

                Text("Опишите ситуацию — остальное соберём сами.")
                    .font(.bcsBody())
                    .foregroundStyle(BCSColor.secondary)
                    .padding(.top, 10)

                BCSPrimaryButton("Создать обращение", systemImage: "square.and.pencil") {
                    router.open(.evidence)
                }
                .accessibilityIdentifier("createCaseButton")
                .padding(.top, 20)

                caseTypes
                    .padding(.top, 16)

                activeCase
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 96)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : BCSMotion.entryOffset(reduceMotion: reduceMotion))
        }
        .background(BCSColor.canvas)
        .onAppear {
            withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                isVisible = true
            }
        }
    }

    private var brandHeader: some View {
        HStack(alignment: .top) {
            HStack(spacing: 14) {
                Text("Better\nCall\nSaul")
                    .font(.bcsEditorial(24))
                    .lineSpacing(-5)
                Rectangle()
                    .fill(BCSColor.yellow)
                    .frame(width: 2, height: 58)
                Text("Всё по закону.")
                    .font(.bcsBody(14))
                    .foregroundStyle(BCSColor.secondary)
            }
            Spacer()
            PayphoneIllustration(lineColor: BCSColor.secondary.opacity(0.55), lineWidth: 1)
                .frame(width: 96, height: 112)
        }
    }

    private var caseTypes: some View {
        VStack(spacing: 0) {
            BCSDivider()
            ForEach(CaseType.allCases) { type in
                Button {
                    router.open(.evidence)
                } label: {
                    HStack(spacing: 15) {
                        Image(systemName: type.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(BCSColor.divider, lineWidth: 1))
                        Text(type.rawValue)
                            .font(.bcsBody(17))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BCSColor.secondary)
                    }
                    .frame(minHeight: 44)
                    .foregroundStyle(BCSColor.ink)
                }
                .accessibilityIdentifier("caseType.\(type == .subscription ? "subscription" : type.id)")
                BCSDivider()
            }
        }
    }

    private var activeCase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("АКТИВНОЕ ОБРАЩЕНИЕ")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(BCSColor.secondary)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(BCSColor.yellow)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Возврат 24 900 ₸")
                        .font(.bcsEditorial(20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(DemoFixtures.activeCase.number)
                        .font(.bcsMeta(10))
                        .foregroundStyle(BCSColor.secondary)
                }
                .layoutPriority(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    BCSStatusBadge(title: "Ожидается ответ", isActive: true)
                    Text("до 28 июля")
                        .font(.bcsBody(13))
                        .foregroundStyle(BCSColor.secondary)
                }
                SaulPhoneTile()
                    .scaleEffect(0.84)
                    .frame(width: 44, height: 44)
            }
            .frame(minHeight: 62)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("activeCaseCard")

            Text("S’all good")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(BCSColor.secondary.opacity(0.6))
                .frame(maxWidth: .infinity)
        }
    }
}
