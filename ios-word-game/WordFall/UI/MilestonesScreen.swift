import SwiftUI

struct MilestonesScreen: View {
    let playerProfile: PlayerProfile
    let onBack: () -> Void

    var body: some View {
        ZStack {
            ParchmentBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                            Text("Menu")
                                .font(StitchTheme.Typography.body(size: 15, weight: .heavy))
                        }
                        .foregroundStyle(StitchTheme.Colors.inkPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(StitchTheme.Colors.surfaceCard)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Milestones")
                        .font(StitchTheme.Typography.title(size: 22))
                        .foregroundStyle(StitchTheme.Colors.inkPrimary)

                    Spacer()

                    Color.clear
                        .frame(width: 80, height: 38)
                }
                .padding(.horizontal, StitchTheme.Space._4)
                .padding(.top, StitchTheme.Space._4)
                .padding(.bottom, StitchTheme.Space._3)

                statsRow
                    .padding(.horizontal, StitchTheme.Space._4)
                    .padding(.bottom, StitchTheme.Space._3)

                ScrollView {
                    VStack(spacing: StitchTheme.Space._3) {
                        ForEach(LifetimeMilestoneID.allCases, id: \.self) { milestoneID in
                            milestoneCard(milestoneID)
                        }
                    }
                    .padding(.horizontal, StitchTheme.Space._4)
                    .padding(.bottom, StitchTheme.Space._5)
                }
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: StitchTheme.Space._2) {
            statPill(label: "Best Round", value: "\(playerProfile.stats.highestRoundReached)")
            statPill(label: "Words", value: "\(playerProfile.stats.totalWordsBuilt)")
            statPill(label: "Locks Broken", value: "\(playerProfile.stats.totalLocksBroken)")
            statPill(label: "Rare Words", value: "\(playerProfile.stats.totalRareLetterWords)")
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(StitchTheme.Typography.body(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(StitchTheme.Colors.inkPrimary)
            Text(label)
                .font(StitchTheme.Typography.labelCaps(size: 10))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(StitchTheme.Colors.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
                .fill(StitchTheme.Colors.surfaceCard)
                .overlay(
                    RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
                        .stroke(StitchTheme.Colors.strokeSoft, lineWidth: StitchTheme.Stroke.hairline)
                )
        )
    }

    // MARK: - Milestone card

    private func milestoneCard(_ milestoneID: LifetimeMilestoneID) -> some View {
        let milestone = milestoneID
        let (current, threshold) = playerProfile.lifetimeMilestoneProgress(for: milestoneID)
        let progress = min(1.0, Double(current) / Double(threshold))
        let unlocked = playerProfile.unlockedLifetimeMilestones.contains(milestoneID)
        let sh = StitchTheme.Shadow.card

        return VStack(alignment: .leading, spacing: StitchTheme.Space._2) {
            HStack(alignment: .top, spacing: StitchTheme.Space._2) {
                Image(systemName: unlocked ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(unlocked ? ParchmentTheme.Palette.footerYellow : StitchTheme.Colors.inkSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(milestone.title)
                        .font(StitchTheme.Typography.body(size: 15, weight: .heavy))
                        .foregroundStyle(StitchTheme.Colors.inkPrimary)

                    Text(milestone.effectDescription)
                        .font(StitchTheme.Typography.caption())
                        .foregroundStyle(StitchTheme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(unlocked ? "✓" : "\(current)/\(threshold)")
                    .font(StitchTheme.Typography.caption(size: 14, weight: .heavy).monospacedDigit())
                    .foregroundStyle(unlocked ? ParchmentTheme.Palette.objectiveGreenText : StitchTheme.Colors.inkPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(StitchTheme.Colors.surfaceCardAlt)
                        .frame(height: 10)
                    Capsule()
                        .fill(unlocked ? ParchmentTheme.Palette.objectiveGreen : ParchmentTheme.Palette.footerBlue)
                        .frame(width: geo.size.width * CGFloat(progress), height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(StitchTheme.Space._4)
        .background(
            RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                .fill(StitchTheme.Colors.surfaceCard)
                .overlay(
                    RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                        .stroke(
                            unlocked ? ParchmentTheme.Palette.objectiveGreen : StitchTheme.Colors.strokeSoft,
                            lineWidth: StitchTheme.Stroke.standard
                        )
                )
        )
        .shadow(color: sh.color.opacity(0.7), radius: sh.radius, x: sh.x, y: sh.y)
    }
}

#Preview {
    MilestonesScreen(
        playerProfile: PlayerProfile(),
        onBack: {}
    )
}
