import SwiftUI

struct RoundClearedOverlay: View {

    struct Info: Equatable {
        let roundIndex: Int
        let act: Int
        let isChallengeRound: Bool
        let challengeDisplayName: String?
        let scoreThisRound: Int
        let scoreGoal: Int
        let movesRemaining: Int
    }

    private enum Chrome {
        static let cardWidth: CGFloat = 300
        static let cornerRadius: CGFloat = StitchTheme.RuunChrome.panelRadius
        static let lineWidth: CGFloat = StitchTheme.RuunChrome.panelLineWidth
        static let depth: CGFloat = StitchTheme.RuunChrome.panelDepth
    }

    let info: Info
    let onNext: () -> Void

    @State private var appeared: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            ZStack {
                StitchRoundedSurface(
                    fill: StitchTheme.BoardGame.canvasWarm,
                    border: StitchTheme.BoardGame.outline,
                    shadow: StitchTheme.BoardGame.outline,
                    cornerRadius: Chrome.cornerRadius,
                    lineWidth: Chrome.lineWidth,
                    depth: Chrome.depth
                )

                VStack(spacing: 0) {
                    headerSection
                    statsSection
                    buttonSection
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: Chrome.cornerRadius, style: .continuous)
                )
            }
            .frame(width: Chrome.cardWidth)
            .padding(.bottom, Chrome.depth)
            .scaleEffect(appeared ? 1 : 0.82)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            let anim: Animation = AppSettings.reduceMotion
                ? .easeOut(duration: 0.14)
                : .spring(response: 0.38, dampingFraction: 0.7)
            withAnimation(anim) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 5) {
            Text(eyebrowText)
                .font(StitchTheme.Typography.labelCaps(size: 11, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(StitchTheme.BoardGame.textSecondary.opacity(0.75))

            Text(titleText)
                .font(StitchTheme.Typography.valueHero(size: 26, weight: .black))
                .tracking(-0.5)
                .foregroundStyle(
                    info.isChallengeRound
                        ? StitchTheme.BoardGame.goldStrong
                        : StitchTheme.BoardGame.textPrimary
                )
                .minimumScaleFactor(0.82)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(
            info.isChallengeRound
                ? StitchTheme.BoardGame.goldWash
                : StitchTheme.BoardGame.canvasWarm
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.15))
                .frame(height: 1.5)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 10) {
            statChip(
                label: "SCORE",
                value: info.scoreThisRound.formatted(),
                detail: "/ \(info.scoreGoal.formatted())",
                symbol: "star.fill"
            )
            statChip(
                label: "MOVES LEFT",
                value: "\(info.movesRemaining)",
                detail: nil,
                symbol: "arrow.right.circle.fill"
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(StitchTheme.BoardGame.canvasWarm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.12))
                .frame(height: 1.5)
        }
    }

    private func statChip(
        label: String,
        value: String,
        detail: String?,
        symbol: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(StitchTheme.BoardGame.goldStrong)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(StitchTheme.Typography.labelCaps(size: 9, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)

                HStack(spacing: 3) {
                    Text(value)
                        .font(StitchTheme.Typography.body(size: 16, weight: .black).monospacedDigit())
                        .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(StitchTheme.Typography.body(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(StitchTheme.BoardGame.textMuted)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.secondaryCardRadius, style: .continuous)
                .fill(StitchTheme.BoardGame.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.secondaryCardRadius, style: .continuous)
                        .stroke(StitchTheme.BoardGame.outline.opacity(0.16), lineWidth: StitchTheme.RuunChrome.secondaryCardLineWidth)
                )
        )
    }

    // MARK: - Button

    private var buttonSection: some View {
        Button(action: onNext) {
            HStack(spacing: 8) {
                Text("NEXT ROUND")
                    .font(StitchTheme.Typography.subtitle(size: 17, weight: .black))
                    .tracking(0.6)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(StitchTheme.BoardGame.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: StitchTheme.RuunChrome.buttonHeight)
            .background(
                StitchRoundedSurface(
                    fill: StitchTheme.BoardGame.gold,
                    border: StitchTheme.BoardGame.outline,
                    shadow: StitchTheme.BoardGame.goldStrong,
                    cornerRadius: StitchTheme.RuunChrome.cardRadius,
                    lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                    depth: StitchTheme.RuunChrome.cardDepth
                )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 14 + StitchTheme.RuunChrome.cardDepth)
        .background(StitchTheme.BoardGame.canvasWarm)
    }

    // MARK: - Derived strings

    private var titleText: String {
        if info.isChallengeRound, let name = info.challengeDisplayName {
            return "\(name.uppercased()) CLEARED"
        }
        return info.isChallengeRound ? "CHALLENGE CLEARED" : "ROUND CLEARED"
    }

    private var eyebrowText: String {
        "ROUND \(String(format: "%02d", info.roundIndex)) · BUCKET \(info.act)"
    }
}

// MARK: - Preview

struct RoundClearedOverlay_Previews: PreviewProvider {
    static var previews: some View {
        RoundClearedOverlay(
            info: RoundClearedOverlay.Info(
                roundIndex: 7,
                act: 1,
                isChallengeRound: false,
                challengeDisplayName: nil,
                scoreThisRound: 284,
                scoreGoal: 230,
                movesRemaining: 4
            ),
            onNext: {}
        )
        .previewDisplayName("Normal Round")

        RoundClearedOverlay(
            info: RoundClearedOverlay.Info(
                roundIndex: 17,
                act: 1,
                isChallengeRound: true,
                challengeDisplayName: "Pyramid",
                scoreThisRound: 410,
                scoreGoal: 360,
                movesRemaining: 2
            ),
            onNext: {}
        )
        .previewDisplayName("Challenge Round")
    }
}
