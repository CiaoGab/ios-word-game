import SwiftUI

enum AppScreen {
    case start
    case game
    case profile
    case howToPlay
    case settings
}

struct ContentView: View {
    @StateObject private var milestoneTracker = MilestoneTracker()
    @StateObject private var playerProfile = PlayerProfile()
    @State private var screen: AppScreen = .start
    @State private var selectedStarterPerks: [StarterPerkID] = []

    var body: some View {
        switch screen {
        case .start:
            StartScreen(
                playerProfile: playerProfile,
                onPlay: { perks in
                    selectedStarterPerks = perks
                    screen = .game
                },
                onProfile: { screen = .profile },
                onHowToPlay: { screen = .howToPlay },
                onSettings: { screen = .settings }
            )
        case .game:
            GameScreen(
                milestoneTracker: milestoneTracker,
                playerProfile: playerProfile,
                starterPerks: selectedStarterPerks,
                onQuitToMenu: { screen = .start }
            )
        case .profile:
            MenuProfileScreen(
                playerProfile: playerProfile,
                onBack: { screen = .start }
            )
        case .howToPlay:
            MenuHowToPlayScreen(
                onBack: { screen = .start }
            )
        case .settings:
            MenuSettingsScreen(
                playerProfile: playerProfile,
                onBack: { screen = .start }
            )
        }
    }
}

private enum MenuChrome {
    static let horizontalPadding: CGFloat = StitchTheme.Space._5
    static let sectionSpacing: CGFloat = StitchTheme.Space._4
    static let rowSpacing: CGFloat = StitchTheme.Space._2
    static let rowMinHeight: CGFloat = 52
    static let panelCornerRadius: CGFloat = StitchTheme.Radii.md
    static let rowCornerRadius: CGFloat = StitchTheme.Radii.sm
    static let topControlWidth: CGFloat = 78
    static let topControlHeight: CGFloat = 32

    static var panelShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (StitchTheme.Colors.shadowColor.opacity(0.09), 5, 0, 2)
    }

    static var controlShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (StitchTheme.Colors.shadowColor.opacity(0.08), 4, 0, 2)
    }
}

private struct MenuScreenShell<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(StitchTheme.Space._2, proxy.safeAreaInsets.top + StitchTheme.Space._1)
            ZStack {
                StitchTheme.Colors.bgCanvas
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ZStack {
                        Text(title)
                            .font(StitchTheme.Typography.subtitle(size: 21, weight: .heavy))
                            .foregroundStyle(StitchTheme.Colors.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        HStack {
                            Button(action: onBack) {
                                HStack(spacing: StitchTheme.Space._1) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .heavy))
                                    Text("Menu")
                                        .font(StitchTheme.Typography.caption(size: 13, weight: .heavy))
                                }
                                .foregroundStyle(StitchTheme.Colors.inkPrimary)
                                .frame(width: MenuChrome.topControlWidth, height: MenuChrome.topControlHeight)
                                .background(MenuTopControlSurface())
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Color.clear
                                .frame(width: MenuChrome.topControlWidth, height: MenuChrome.topControlHeight)
                        }
                    }
                    .padding(.horizontal, MenuChrome.horizontalPadding)
                    .padding(.top, topInset)
                    .padding(.bottom, StitchTheme.Space._2)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: MenuChrome.sectionSpacing) {
                            content()
                        }
                        .padding(.horizontal, MenuChrome.horizontalPadding)
                        .padding(.bottom, StitchTheme.Space._6)
                    }
                }
            }
        }
    }
}

private struct MenuTopControlSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
            .fill(StitchTheme.Colors.surfaceCardAlt)
            .overlay(
                RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
                    .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
            )
            .shadow(
                color: MenuChrome.controlShadow.color,
                radius: MenuChrome.controlShadow.radius,
                x: MenuChrome.controlShadow.x,
                y: MenuChrome.controlShadow.y
            )
    }
}

private struct MenuSectionHeading: View {
    let title: String
    let symbol: String?

    init(_ title: String, symbol: String? = nil) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: StitchTheme.Space._2) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(StitchTheme.Colors.inkSecondary)
            }
            Text(title.uppercased())
                .font(StitchTheme.Typography.labelCaps(size: 12, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(StitchTheme.Colors.inkSecondary)
            Spacer(minLength: 0)
        }
    }
}

private struct MenuSectionCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(StitchTheme.Space._3)
            .background(
                RoundedRectangle(cornerRadius: MenuChrome.panelCornerRadius, style: .continuous)
                    .fill(StitchTheme.Colors.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: MenuChrome.panelCornerRadius, style: .continuous)
                            .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
            .shadow(
                color: MenuChrome.panelShadow.color,
                radius: MenuChrome.panelShadow.radius,
                x: MenuChrome.panelShadow.x,
                y: MenuChrome.panelShadow.y
            )
    }
}

private struct MenuInsetRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: MenuChrome.rowMinHeight)
            .background(
                RoundedRectangle(cornerRadius: MenuChrome.rowCornerRadius, style: .continuous)
                    .fill(StitchTheme.Colors.surfaceCardAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: MenuChrome.rowCornerRadius, style: .continuous)
                            .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
    }
}

private struct MenuProfileScreen: View {
    let playerProfile: PlayerProfile
    let onBack: () -> Void

    private enum ProfileChrome {
        static let horizontalPadding: CGFloat = StitchTheme.RuunChrome.screenHorizontalPadding
        static let sectionSpacing: CGFloat = StitchTheme.RuunChrome.sectionSpacing
        static let cardRadius: CGFloat = StitchTheme.RuunChrome.cardRadius
        static let tileRadius: CGFloat = 16
        static let depth: CGFloat = StitchTheme.RuunChrome.cardDepth
    }

    private let unlockColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(16, proxy.safeAreaInsets.top + 8)
            let bottomInset = max(28, proxy.safeAreaInsets.bottom + 16)

            ZStack {
                StitchTheme.BoardGame.canvasWarm
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topInset: topInset)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: ProfileChrome.sectionSpacing) {
                            heroSection
                            summaryRow
                            progressSection
                            milestonesSection
                            unlockablesSection
                        }
                        .padding(.horizontal, ProfileChrome.horizontalPadding)
                        .padding(.top, 16)
                        .padding(.bottom, bottomInset)
                    }
                }
            }
        }
    }

    private func header(topInset: CGFloat) -> some View {
        ZStack {
            Text("PROFILE")
                .font(StitchTheme.Typography.subtitle(size: 20, weight: .heavy))
                .tracking(0.9)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)

            HStack {
                Button(action: onBack) {
                    RuunHeaderControl(systemImage: "arrow.left", iconSize: 16)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)

                Spacer(minLength: 0)

                Color.clear
                    .frame(
                        width: StitchTheme.RuunChrome.headerControlSize,
                        height: StitchTheme.RuunChrome.headerControlSize
                    )
            }
        }
        .padding(.horizontal, ProfileChrome.horizontalPadding)
        .padding(.top, topInset)
        .padding(.bottom, StitchTheme.RuunChrome.headerBottomPadding)
        .background(StitchTheme.BoardGame.canvasWarm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.18))
                .frame(height: 2)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: ProfileChrome.cardRadius, style: .continuous)
                        .fill(StitchTheme.BoardGame.goldWash.opacity(0.9))

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x1A3A5F), StitchTheme.BoardGame.textPrimary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(8)

                    Image(systemName: "figure.run")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                .frame(width: 112, height: 112)
                .background(
                    StitchRoundedSurface(
                        fill: .clear,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.gold,
                        cornerRadius: ProfileChrome.cardRadius,
                        lineWidth: 3,
                        depth: 6
                    )
                )
                .padding(.bottom, 6)

                Text("T\(playerProfile.perkLibraryTier)")
                    .font(StitchTheme.Typography.caption(size: 11, weight: .black))
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(StitchTheme.BoardGame.gold)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(StitchTheme.BoardGame.outline, lineWidth: 2)
                            )
                    )
                    .offset(x: 8, y: 8)
            }

            VStack(spacing: 4) {
                Text("PROFILE XP")
                    .font(StitchTheme.Typography.labelCaps(size: 12, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(StitchTheme.BoardGame.goldStrong)

                Text(playerProfile.totalXP.formatted())
                    .font(StitchTheme.Typography.valueHero(size: 34, weight: .black).monospacedDigit())
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .black))
                    Text("PERK LIBRARY TIER \(playerProfile.perkLibraryTier)")
                        .font(StitchTheme.Typography.labelCaps(size: 13, weight: .heavy))
                        .tracking(1.1)
                }
                .foregroundStyle(StitchTheme.BoardGame.goldStrong)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryStatTile(label: "Runs Won", value: playerProfile.stats.runsCompleted.formatted(), accent: false)
            summaryStatTile(label: "Perk Tier", value: "T\(playerProfile.perkLibraryTier)", accent: true)
            summaryStatTile(label: "Best Round", value: playerProfile.stats.highestRoundReached.formatted(), accent: false)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextUnlock == nil ? "MAX PROGRESSION" : "CURRENT PROGRESS")
                        .font(StitchTheme.Typography.labelCaps(size: 11, weight: .heavy))
                        .tracking(0.9)
                        .foregroundStyle(StitchTheme.BoardGame.goldStrong)

                    Text(nextUnlock?.title ?? "All Unlocks Earned")
                        .font(StitchTheme.Typography.subtitle(size: 18, weight: .black))
                        .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                }

                Spacer(minLength: 8)

                Text(progressText)
                    .font(StitchTheme.Typography.body(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(StitchTheme.BoardGame.surfaceMuted)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(StitchTheme.BoardGame.outline, lineWidth: 2)
                        )

                    Capsule(style: .continuous)
                        .fill(StitchTheme.BoardGame.gold)
                        .frame(width: max(20, (geo.size.width - 4) * progressFraction))
                        .padding(2)
                }
            }
            .frame(height: 24)

            Text(progressFootnote)
                .font(StitchTheme.Typography.caption(size: 12, weight: .medium))
                .foregroundStyle(StitchTheme.BoardGame.textSecondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.cardRadius, style: .continuous)
                .fill(StitchTheme.BoardGame.surfaceWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileChrome.cardRadius, style: .continuous)
                        .stroke(
                            StitchTheme.BoardGame.gold.opacity(0.72),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                        )
                )
        )
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(title: "Milestones", symbol: "trophy.fill")

            VStack(spacing: 12) {
                ForEach(LifetimeMilestoneID.allCases, id: \.self) { milestoneID in
                    milestoneCard(milestoneID)
                }
            }
        }
    }

    private func milestoneCard(_ milestoneID: LifetimeMilestoneID) -> some View {
        let (current, threshold) = playerProfile.lifetimeMilestoneProgress(for: milestoneID)
        let unlocked = playerProfile.unlockedLifetimeMilestones.contains(milestoneID)
        let fillRatio = min(1, CGFloat(current) / CGFloat(max(1, threshold)))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                    .fill(unlocked ? StitchTheme.BoardGame.goldWash : StitchTheme.BoardGame.surfaceMuted.opacity(0.58))
                    .frame(width: StitchTheme.RuunChrome.iconChipSize, height: StitchTheme.RuunChrome.iconChipSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                            .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)
                    }
                    .overlay {
                        Image(systemName: milestoneSymbol(milestoneID))
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(unlocked ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textSecondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(milestoneID.title)
                        .font(StitchTheme.Typography.body(size: 15, weight: .heavy))
                        .foregroundStyle(StitchTheme.BoardGame.textPrimary)

                    Text(milestoneID.effectDescription)
                        .font(StitchTheme.Typography.caption(size: 12, weight: .semibold))
                        .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(unlocked ? "CLEARED" : "\(current)/\(threshold)")
                    .font(StitchTheme.Typography.caption(size: 12, weight: .black).monospacedDigit())
                    .foregroundStyle(unlocked ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(StitchTheme.BoardGame.surfaceMuted.opacity(0.8))

                    Capsule(style: .continuous)
                        .fill(unlocked ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.textPrimary.opacity(0.82))
                        .frame(width: geo.size.width * fillRatio)
                }
            }
            .frame(height: 10)
        }
        .padding(14)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surface,
                border: StitchTheme.BoardGame.outline,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: ProfileChrome.cardRadius,
                lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                depth: ProfileChrome.depth
            )
        )
        .padding(.bottom, ProfileChrome.depth)
    }

    private var unlockablesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(title: "Unlockables", symbol: "lock.open.fill")

            LazyVGrid(columns: unlockColumns, spacing: 16) {
                ForEach(ProfileUnlockID.allCases, id: \.self) { unlock in
                    unlockCard(unlock)
                }
            }
        }
    }

    private func unlockCard(_ unlock: ProfileUnlockID) -> some View {
        let isUnlocked = playerProfile.unlockedThresholds.contains(unlock)
        let isNext = nextUnlock == unlock

        return VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isUnlocked ? StitchTheme.BoardGame.goldWash : StitchTheme.BoardGame.surfaceMuted.opacity(0.45))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: unlockSymbol(unlock))
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(isUnlocked ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textMuted)
                }

            Text(unlock.title.uppercased())
                .font(StitchTheme.Typography.labelCaps(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)

            VStack(spacing: 2) {
                Text(isUnlocked ? "UNLOCKED" : unlock.phaseLabel.uppercased())
                    .font(StitchTheme.Typography.caption(size: 11, weight: .black))
                    .foregroundStyle(isUnlocked ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textSecondary)

                Text("\(unlock.threshold.formatted()) XP")
                    .font(StitchTheme.Typography.caption(size: 11, weight: .semibold))
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 146)
        .padding(18)
        .background(unlockCardSurface(isUnlocked: isUnlocked, isNext: isNext))
    }

    private func unlockCardSurface(isUnlocked: Bool, isNext: Bool) -> some View {
        let fill = isNext ? StitchTheme.BoardGame.surfaceWarm : StitchTheme.BoardGame.surface
        let borderColor = isNext ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.outline
        let shadowColor = isUnlocked ? StitchTheme.BoardGame.outline : StitchTheme.BoardGame.outline.opacity(0.88)

        return Group {
            if isNext {
                RoundedRectangle(cornerRadius: ProfileChrome.cardRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: ProfileChrome.cardRadius, style: .continuous)
                            .stroke(borderColor, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    )
            } else {
                StitchRoundedSurface(
                    fill: fill,
                    border: borderColor,
                    shadow: shadowColor,
                    cornerRadius: ProfileChrome.cardRadius,
                    lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                    depth: ProfileChrome.depth
                )
            }
        }
    }

    private func summaryStatTile(label: String, value: String, accent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(StitchTheme.BoardGame.textSecondary)

            Text(value)
                .font(StitchTheme.Typography.subtitle(size: 18, weight: .black).monospacedDigit())
                .foregroundStyle(accent ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 74)
        .padding(.horizontal, 8)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surface,
                border: StitchTheme.BoardGame.outline,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: ProfileChrome.cardRadius,
                lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                depth: ProfileChrome.depth
            )
        )
        .padding(.bottom, ProfileChrome.depth)
    }

    private func sectionHeading(title: String, symbol: String) -> some View {
        RuunSectionHeading(title: title, symbol: symbol)
    }

    private var nextUnlock: ProfileUnlockID? {
        playerProfile.nextLockedUnlock
    }

    private var progressText: String {
        guard let nextUnlock else { return "MAXED" }
        return "\(min(playerProfile.totalXP, nextUnlock.threshold).formatted()) / \(nextUnlock.threshold.formatted()) XP"
    }

    private var progressFootnote: String {
        guard let nextUnlock else { return "All XP-based unlocks have been earned." }
        return "\(nextUnlock.phaseLabel) unlock at \(nextUnlock.threshold.formatted()) XP."
    }

    private var progressFraction: CGFloat {
        guard let nextUnlock else { return 1 }
        return min(1, CGFloat(playerProfile.totalXP) / CGFloat(max(1, nextUnlock.threshold)))
    }

    private func milestoneSymbol(_ milestone: LifetimeMilestoneID) -> String {
        switch milestone {
        case .build100Words:
            return "textformat.abc"
        case .break150Locks:
            return "lock.open.fill"
        case .use25RareLetterWords:
            return "sparkles"
        case .reachRound20:
            return "flag.checkered"
        }
    }

    private func unlockSymbol(_ unlock: ProfileUnlockID) -> String {
        switch unlock {
        case .equipSlot1, .equipSlot2, .equipSlot3, .equipSlot4:
            return "square.grid.2x2.fill"
        case .perkLibraryTier2, .perkLibraryTier3:
            return "books.vertical.fill"
        case .rerollPerRun:
            return "arrow.clockwise.circle.fill"
        case .startingPowerup:
            return "bolt.fill"
        case .challengeInsight:
            return "eye.fill"
        case .ascension1:
            return "arrow.up.forward.circle.fill"
        }
    }
}

private struct MenuHowToPlayScreen: View {
    let onBack: () -> Void

    private struct HelpSection: Identifiable {
        enum Accent: Equatable {
            case neutral
            case gold
        }

        let id: String
        let title: String
        let symbol: String
        let body: String
        let accent: Accent
    }

    private let sections: [HelpSection] = [
        HelpSection(
            id: "objective",
            title: "The Objective",
            symbol: "scope",
            body: "Build valid words, clear locks, and push as far as you can through the full run.",
            accent: .neutral
        ),
        HelpSection(
            id: "turn",
            title: "How to Play",
            symbol: "hand.tap.fill",
            body: "Select connected letters to form a word, then submit. Valid words score points and update the board.",
            accent: .neutral
        ),
        HelpSection(
            id: "locks",
            title: "Locks & Progression",
            symbol: "lock.fill",
            body: "Locked tiles limit your options. Break locks with strong plays, then use your profile progression to unlock stronger run prep.",
            accent: .neutral
        ),
        HelpSection(
            id: "acts",
            title: "Acts & Rounds",
            symbol: "flag.2.crossed.fill",
            body: "Runs are split across acts and rounds with rising pressure. Challenge rounds test consistency and reward clean execution.",
            accent: .neutral
        ),
        HelpSection(
            id: "tips",
            title: "Pro Tips",
            symbol: "lightbulb.fill",
            body: "Favor stable clears over risky long shots early. Save premium tools for heavy lock states and momentum swings.",
            accent: .gold
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(16, proxy.safeAreaInsets.top + 8)
            let bottomInset = max(18, proxy.safeAreaInsets.bottom + 10)

            ZStack {
                StitchTheme.BoardGame.canvasWarm
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topInset: topInset)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(sections) { section in
                                instructionCard(section)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footerCTA(bottomInset: bottomInset)
            }
        }
    }

    private func header(topInset: CGFloat) -> some View {
        ZStack {
            Text("HOW TO PLAY")
                .font(StitchTheme.Typography.subtitle(size: 19, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)

            HStack {
                Button(action: onBack) {
                    RuunHeaderControl(systemImage: "arrow.left", iconSize: 18)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)

                Spacer(minLength: 0)

                Color.clear
                    .frame(
                        width: StitchTheme.RuunChrome.headerControlSize,
                        height: StitchTheme.RuunChrome.headerControlSize
                    )
            }
        }
        .padding(.horizontal, StitchTheme.RuunChrome.screenHorizontalPadding)
        .padding(.top, topInset)
        .padding(.bottom, StitchTheme.RuunChrome.headerBottomPadding)
        .background(StitchTheme.BoardGame.canvasWarm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.18))
                .frame(height: 2)
        }
    }

    private func instructionCard(_ section: HelpSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                iconChip(symbol: section.symbol, accent: section.accent)

                Text(section.title.uppercased())
                    .font(StitchTheme.Typography.body(size: 18, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }

            Text(section.body)
                .font(StitchTheme.Typography.body(size: 15, weight: .medium))
                .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surface,
                border: StitchTheme.BoardGame.outline,
                shadow: StitchTheme.BoardGame.gold,
                cornerRadius: StitchTheme.RuunChrome.cardRadius,
                lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                depth: StitchTheme.RuunChrome.cardDepth
            )
        )
        .padding(.bottom, StitchTheme.RuunChrome.cardDepth)
    }

    private func iconChip(symbol: String, accent: HelpSection.Accent) -> some View {
        let fill = accent == .gold ? StitchTheme.BoardGame.gold.opacity(0.92) : StitchTheme.BoardGame.surfaceWarm

        return ZStack {
            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                .fill(fill)

            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
        }
        .frame(width: StitchTheme.RuunChrome.iconChipSize, height: StitchTheme.RuunChrome.iconChipSize)
    }

    private func footerCTA(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.18))
                .frame(height: 2)

            Button(action: onBack) {
                HStack(spacing: 10) {
                    Text("GOT IT, LET'S PLAY")
                        .font(StitchTheme.Typography.body(size: 18, weight: .heavy))
                        .tracking(1.2)

                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: StitchTheme.RuunChrome.buttonHeight)
                .background(
                    StitchRoundedSurface(
                        fill: StitchTheme.BoardGame.textPrimary,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.gold,
                        cornerRadius: StitchTheme.RuunChrome.buttonRadius,
                        lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                        depth: StitchTheme.RuunChrome.buttonDepth
                    )
                )
                .padding(.bottom, StitchTheme.RuunChrome.buttonDepth)
            }
            .buttonStyle(ParchmentPressStyle())
            .padding(.horizontal, StitchTheme.RuunChrome.screenHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, bottomInset)
        }
        .background(StitchTheme.BoardGame.canvasWarm.opacity(0.98))
    }
}

private struct MenuSettingsScreen: View {
    let playerProfile: PlayerProfile
    let onBack: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(16, proxy.safeAreaInsets.top + 8)
            let bottomInset = max(28, proxy.safeAreaInsets.bottom + 12)

            ZStack {
                StitchTheme.BoardGame.canvasWarm
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    settingsHeader(topInset: topInset)

                    ScrollView(showsIndicators: false) {
                        RuunSettingsContent(
                            playerProfile: playerProfile,
                            bottomPadding: bottomInset
                        )
                        .padding(.horizontal, SettingsScreenChrome.horizontalPadding)
                        .padding(.top, 24)
                    }
                }
            }
        }
    }

    private func settingsHeader(topInset: CGFloat) -> some View {
        ZStack {
            Text("SETTINGS")
                .font(StitchTheme.Typography.subtitle(size: 20, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)

            HStack {
                Button(action: onBack) {
                    RuunHeaderControl(systemImage: "arrow.left", iconSize: 18)
                }
                .buttonStyle(.plain)

                Spacer()

                Color.clear
                    .frame(
                        width: StitchTheme.RuunChrome.headerControlSize,
                        height: StitchTheme.RuunChrome.headerControlSize
                    )
            }
        }
        .padding(.horizontal, SettingsScreenChrome.horizontalPadding)
        .padding(.top, topInset)
        .padding(.bottom, StitchTheme.RuunChrome.headerBottomPadding)
        .background(StitchTheme.BoardGame.canvasWarm.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.18))
                .frame(height: 2)
        }
    }
}

private enum SettingsScreenChrome {
    static let horizontalPadding: CGFloat = StitchTheme.RuunChrome.screenHorizontalPadding
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuProfileScreen(
                playerProfile: PlayerProfile(),
                onBack: {}
            )

            MenuHowToPlayScreen(
                onBack: {}
            )

            MenuSettingsScreen(
                playerProfile: PlayerProfile(),
                onBack: {}
            )

            ContentView()
        }
    }
}
