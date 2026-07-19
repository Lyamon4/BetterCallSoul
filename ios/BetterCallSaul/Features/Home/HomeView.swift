import SwiftUI

struct HomeView: View {
    let router: AppRouter
    @Bindable var workflow: CaseWorkflowStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isSaulTipVisible = false
    @State private var saulTipIndex = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                    .padding(.bottom, 16)

                if isSaulTipVisible {
                    SaulTipBubble(text: SaulHelpCopy.line(at: saulTipIndex))
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

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
                    beginCase(.subscription)
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
        .onDisappear {
            isSaulTipVisible = false
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
            Button {
                withAnimation(BCSMotion.spring(reduceMotion: reduceMotion)) {
                    if isSaulTipVisible {
                        isSaulTipVisible = false
                        saulTipIndex = (saulTipIndex + 1) % SaulHelpCopy.lines.count
                    } else {
                        isSaulTipVisible = true
                    }
                }
            } label: {
                SaulMascotView(
                    state: isSaulTipVisible ? .talking : .idle,
                    size: 96,
                    isDecorative: false
                )
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Сол, помощник")
            .accessibilityHint("Показывает короткую подсказку")
            .accessibilityIdentifier("saulMascotButton")
        }
    }

    private var caseTypes: some View {
        VStack(spacing: 0) {
            BCSDivider()
            ForEach(CaseType.allCases) { type in
                Button {
                    beginCase(type)
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
                    Text(workflow.currentCase.title)
                        .font(.bcsEditorial(20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(workflow.currentCase.number)
                        .font(.bcsMeta(10))
                        .foregroundStyle(BCSColor.secondary)
                }
                .layoutPriority(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    BCSStatusBadge(title: workflow.currentCase.status.rawValue, isActive: true)
                    Text(activeCaseDeadline)
                        .font(.bcsBody(13))
                        .foregroundStyle(BCSColor.secondary)
                }
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

    private func beginCase(_ type: CaseType) {
        isSaulTipVisible = false
        if !ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            workflow.start(type: type)
        }
        router.open(.evidence)
    }

    private var activeCaseDeadline: String {
        guard let deadline = workflow.currentCase.responseDeadline else {
            return "Черновик"
        }
        return "до \(deadline.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))))"
    }
}
