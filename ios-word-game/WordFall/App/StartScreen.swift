import SwiftUI

private enum StartScreenChrome {
    static let horizontalPadding: CGFloat = StitchTheme.RuunChrome.screenHorizontalPadding
    static let heroBottomPadding: CGFloat = 64
    static let actionWidth: CGFloat = 320
    static let primaryHeight: CGFloat = 60
    static let secondaryHeight: CGFloat = StitchTheme.RuunChrome.buttonHeight
    static let actionSpacing: CGFloat = 20
    static let secondarySpacing: CGFloat = 16
    static let buttonCornerRadius: CGFloat = StitchTheme.RuunChrome.buttonRadius
    static let buttonDepth: CGFloat = StitchTheme.RuunChrome.buttonDepth
    static let heroBlue = Color(hex: 0x1A3A5F)
}

struct StartScreen: View {
    let playerProfile: PlayerProfile
    let onPlay: ([StarterPerkID]) -> Void
    let onProfile: () -> Void
    let onHowToPlay: () -> Void
    let onSettings: () -> Void

    @State private var showEquipScreen = false

    var body: some View {
        ZStack {
            StitchTheme.BoardGame.canvasWarm
                .ignoresSafeArea()

            Circle()
                .fill(StitchTheme.BoardGame.gold.opacity(0.08))
                .frame(width: 168, height: 168)
                .blur(radius: 28)
                .offset(x: -132, y: -252)
                .allowsHitTesting(false)

            Circle()
                .fill(StartScreenChrome.heroBlue.opacity(0.05))
                .frame(width: 220, height: 220)
                .blur(radius: 34)
                .offset(x: 150, y: 214)
                .allowsHitTesting(false)

            GeometryReader { proxy in
                let topInset = max(24, proxy.safeAreaInsets.top + 8)
                let bottomInset = max(36, proxy.safeAreaInsets.bottom + 20)

                VStack(spacing: 0) {
                    HStack {
                        Spacer()

                        Button(action: onSettings) {
                            RuunHeaderControl(
                                systemImage: "gearshape",
                                iconSize: 19,
                                fill: StitchTheme.BoardGame.surface.opacity(0.96)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, topInset)
                    .padding(.horizontal, StartScreenChrome.horizontalPadding)

                    Spacer(minLength: 28)

                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            Text("RU")
                                .foregroundStyle(StitchTheme.BoardGame.gold)
                            Text("UN")
                                .foregroundStyle(StartScreenChrome.heroBlue)
                        }
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .tracking(-3.6)
                        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                        .accessibilityLabel("RUUN")

                        Capsule(style: .continuous)
                            .fill(StitchTheme.BoardGame.gold.opacity(0.7))
                            .frame(width: 96, height: 4)

                        Text("THE STRATEGY RACE")
                            .font(StitchTheme.Typography.labelCaps(size: 14, weight: .heavy))
                            .tracking(4.2)
                            .foregroundStyle(StitchTheme.BoardGame.textMuted)
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, StartScreenChrome.heroBottomPadding)

                    VStack(spacing: StartScreenChrome.actionSpacing) {
                        Button(action: { showEquipScreen = true }) {
                            Text("START RUN")
                                .font(StitchTheme.Typography.subtitle(size: 20, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: StartScreenChrome.primaryHeight)
                                .background(
                                    StitchRoundedSurface(
                                        fill: StitchTheme.BoardGame.gold,
                                        border: StitchTheme.BoardGame.outline,
                                        shadow: StitchTheme.BoardGame.goldStrong,
                                        cornerRadius: StartScreenChrome.buttonCornerRadius,
                                        lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                                        depth: StartScreenChrome.buttonDepth
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, StartScreenChrome.buttonDepth)

                        VStack(spacing: StartScreenChrome.secondarySpacing) {
                            homeSecondaryButton(
                                title: "Profile",
                                systemImage: "person.crop.circle",
                                action: onProfile
                            )
                            homeSecondaryButton(
                                title: "How to Play",
                                systemImage: "questionmark.circle",
                                action: onHowToPlay
                            )
                        }
                    }
                    .frame(maxWidth: StartScreenChrome.actionWidth)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: bottomInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showEquipScreen) {
            PreRunEquipView(
                playerProfile: playerProfile,
                initialSelection: playerProfile.equippedStarterPerks,
                onCancel: { showEquipScreen = false },
                onStart: { perks in
                    playerProfile.setEquippedStarterPerks(perks)
                    showEquipScreen = false
                    onPlay(perks)
                }
            )
        }
    }

    private func homeSecondaryButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)

                Text(title)
                    .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: StartScreenChrome.secondaryHeight)
                .background(
                    StitchRoundedSurface(
                        fill: StitchTheme.BoardGame.surface,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.outline,
                        cornerRadius: StartScreenChrome.buttonCornerRadius,
                        lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                        depth: StartScreenChrome.buttonDepth
                    )
                )
        }
        .buttonStyle(.plain)
        .padding(.bottom, StartScreenChrome.buttonDepth)
    }
}

struct StartScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartScreen(
            playerProfile: PlayerProfile(),
            onPlay: { _ in },
            onProfile: {},
            onHowToPlay: {},
            onSettings: {}
        )
    }
}
