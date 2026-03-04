import SwiftUI

struct RunSummaryView: View {
    let boardReached: Int
    let wonRun: Bool
    let milestoneTracker: MilestoneTracker
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: ParchmentTheme.Spacing.lg) {
                    titleSection
                    summaryStatsSection
                    milestonesSection
                    if !milestoneTracker.justUnlocked.isEmpty {
                        newUnlocksSection
                    }
                    dismissButton
                }
                .padding(ParchmentTheme.Spacing.xl)
            }
            .background(
                RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.panel, style: .continuous)
                    .fill(ParchmentTheme.Palette.paperBase)
                    .overlay(
                        RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.panel, style: .continuous)
                            .stroke(ParchmentTheme.Palette.ink.opacity(0.88), lineWidth: ParchmentOverlayStyle.Stroke.panel)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.panel, style: .continuous))
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(0.18),
                radius: ParchmentOverlayStyle.Tunables.panelShadowRadius,
                x: 0,
                y: ParchmentOverlayStyle.Tunables.panelShadowY
            )
            .padding(.horizontal, ParchmentTheme.Spacing.lg)
            .padding(.vertical, 48)
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(spacing: ParchmentTheme.Spacing.xs) {
            Text(wonRun ? "Nice Run!" : "Run Ended")
                .font(.parchmentRounded(size: 34, weight: .heavy))
                .foregroundStyle(wonRun
                    ? ParchmentTheme.Palette.objectiveGreenText
                    : ParchmentTheme.Palette.footerRed)

            Text(subtitle)
                .font(.parchmentRounded(size: 15, weight: .bold))
                .foregroundStyle(ParchmentTheme.Palette.slate)
        }
    }

    private var subtitle: String {
        if wonRun {
            return "You cleared all \(RunState.Tunables.totalBoards) boards!"
        }
        return "Board \(boardReached)/\(RunState.Tunables.totalBoards) reached."
    }

    private var summaryStatsSection: some View {
        HStack(spacing: ParchmentTheme.Spacing.sm) {
            summaryStatCard(
                label: "Board Reached",
                value: "\(boardReached)/\(RunState.Tunables.totalBoards)"
            )
            summaryStatCard(
                label: "Locks Broken",
                value: "\(milestoneTracker.counters.totalLocksBroken)"
            )
            summaryStatCard(
                label: "Perks Unlocked",
                value: "\(milestoneTracker.unlockedPerks.count)"
            )
        }
    }

    private func summaryStatCard(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.parchmentRounded(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(ParchmentTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.parchmentRounded(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(ParchmentTheme.Palette.slate)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.stat, style: .continuous)
                .fill(ParchmentTheme.Palette.white)
                .overlay(
                    RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.stat, style: .continuous)
                        .stroke(ParchmentTheme.Palette.ink.opacity(0.22), lineWidth: 2)
                )
        )
        .shadow(color: ParchmentTheme.Palette.ink.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: ParchmentTheme.Spacing.sm) {
            Text("Key Milestones")
                .font(.parchmentRounded(size: 16, weight: .heavy))
                .foregroundStyle(ParchmentTheme.Palette.ink)

            ForEach(MilestoneID.allCases, id: \.self) { milestoneID in
                milestoneRow(milestoneID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ParchmentTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.stat, style: .continuous)
                .fill(ParchmentTheme.Palette.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.stat, style: .continuous)
                        .stroke(ParchmentTheme.Palette.ink.opacity(0.2), lineWidth: 2)
                )
        )
    }

    private var newUnlocksSection: some View {
        VStack(alignment: .leading, spacing: ParchmentTheme.Spacing.sm) {
            Text("New Unlocks")
                .font(.parchmentRounded(size: 17, weight: .heavy))
                .foregroundStyle(ParchmentTheme.Palette.footerYellowStroke)

            ForEach(milestoneTracker.justUnlocked, id: \.self) { perkID in
                HStack(spacing: ParchmentTheme.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(ParchmentTheme.Palette.footerYellowStroke)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(perkID.definition.name)
                            .font(.parchmentRounded(size: 16, weight: .heavy))
                            .foregroundStyle(ParchmentTheme.Palette.ink)
                        Text(perkID.definition.description)
                            .font(.parchmentRounded(size: 13, weight: .bold))
                            .foregroundStyle(ParchmentTheme.Palette.slate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ParchmentTheme.Palette.white.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(ParchmentTheme.Palette.footerYellowStroke.opacity(0.35), lineWidth: 1.5)
                        )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ParchmentTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.stat, style: .continuous)
                .fill(ParchmentTheme.Palette.levelYellow.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.stat, style: .continuous)
                        .stroke(ParchmentTheme.Palette.footerYellowStroke, lineWidth: 2)
                )
        )
        .shadow(color: ParchmentTheme.Palette.ink.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("Back to Menu")
                .font(.parchmentRounded(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                        .fill(ParchmentTheme.Palette.objectiveGreen)
                        .overlay(
                            RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                                .stroke(ParchmentTheme.Palette.objectiveGreenText, lineWidth: 3)
                        )
                )
        }
        .buttonStyle(ParchmentPressStyle())
    }

    // MARK: - Milestone row

    private func milestoneRow(_ milestoneID: MilestoneID) -> some View {
        let milestone = milestoneID.definition
        let (current, threshold) = milestoneTracker.milestoneProgress(for: milestoneID)
        let progress = min(1.0, Double(current) / Double(threshold))
        let unlocked = milestoneTracker.unlockedPerks.contains(milestone.unlocksPerkID)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(milestone.description)
                    .font(.parchmentRounded(size: 13, weight: .bold))
                    .foregroundStyle(ParchmentTheme.Palette.slate)
                Spacer()
                Text(unlocked ? "✓ Unlocked" : "\(current)/\(threshold)")
                    .font(.parchmentRounded(size: 12, weight: .bold))
                    .foregroundStyle(unlocked
                        ? ParchmentTheme.Palette.objectiveGreenText
                        : ParchmentTheme.Palette.ink)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ParchmentTheme.Palette.paperDust)
                        .frame(height: 9)
                    Capsule()
                        .fill(unlocked
                            ? ParchmentTheme.Palette.objectiveGreen
                            : ParchmentTheme.Palette.footerBlue)
                        .frame(width: geo.size.width * CGFloat(progress), height: 9)
                }
            }
            .frame(height: 9)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ParchmentTheme.Palette.paperBase.opacity(0.65))
        )
    }
}

#Preview {
    RunSummaryView(
        boardReached: 5,
        wonRun: false,
        milestoneTracker: MilestoneTracker(),
        onDismiss: {}
    )
}
