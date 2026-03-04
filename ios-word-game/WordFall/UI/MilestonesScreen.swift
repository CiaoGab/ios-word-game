import SwiftUI

struct MilestonesScreen: View {
    let milestoneTracker: MilestoneTracker
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
                                .font(.parchmentRounded(size: 15, weight: .heavy))
                        }
                        .foregroundStyle(ParchmentTheme.Palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ParchmentTheme.Palette.white)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(ParchmentTheme.Palette.ink, lineWidth: ParchmentTheme.Stroke.hud)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Milestones")
                        .font(.parchmentRounded(size: 22, weight: .heavy))
                        .foregroundStyle(ParchmentTheme.Palette.ink)

                    Spacer()

                    // Invisible balance element matching the back button width
                    Color.clear
                        .frame(width: 80, height: 38)
                }
                .padding(.horizontal, ParchmentTheme.Spacing.lg)
                .padding(.top, ParchmentTheme.Spacing.lg)
                .padding(.bottom, ParchmentTheme.Spacing.md)

                // Stats row
                statsRow
                    .padding(.horizontal, ParchmentTheme.Spacing.lg)
                    .padding(.bottom, ParchmentTheme.Spacing.md)

                // Milestone cards
                ScrollView {
                    VStack(spacing: ParchmentTheme.Spacing.md) {
                        ForEach(MilestoneID.allCases, id: \.self) { milestoneID in
                            milestoneCard(milestoneID)
                        }
                    }
                    .padding(.horizontal, ParchmentTheme.Spacing.lg)
                    .padding(.bottom, ParchmentTheme.Spacing.xl)
                }
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: ParchmentTheme.Spacing.sm) {
            statPill(
                label: "Best Round",
                value: "\(milestoneTracker.counters.bestRoundReached)"
            )
            statPill(
                label: "Runs",
                value: "\(milestoneTracker.counters.runsCompleted)"
            )
            statPill(
                label: "Locks Broken",
                value: "\(milestoneTracker.counters.totalLocksBroken)"
            )
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.parchmentRounded(size: 20, weight: .heavy).monospacedDigit())
                .foregroundStyle(ParchmentTheme.Palette.ink)
            Text(label)
                .font(.parchmentRounded(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(ParchmentTheme.Palette.slate)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ParchmentTheme.Palette.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ParchmentTheme.Palette.ink.opacity(0.18), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Milestone card

    private func milestoneCard(_ milestoneID: MilestoneID) -> some View {
        let milestone = milestoneID.definition
        let (current, threshold) = milestoneTracker.milestoneProgress(for: milestoneID)
        let progress = min(1.0, Double(current) / Double(threshold))
        let unlocked = milestoneTracker.unlockedPerks.contains(milestone.unlocksPerkID)
        let perk = milestone.unlocksPerkID.definition

        return VStack(alignment: .leading, spacing: ParchmentTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: ParchmentTheme.Spacing.sm) {
                Image(systemName: unlocked ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(unlocked
                        ? ParchmentTheme.Palette.footerYellow
                        : ParchmentTheme.Palette.slate)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(milestone.description)
                        .font(.parchmentRounded(size: 15, weight: .heavy))
                        .foregroundStyle(ParchmentTheme.Palette.ink)

                    Text("Unlocks \(perk.name) — \(perk.description)")
                        .font(.parchmentRounded(size: 12, weight: .bold))
                        .foregroundStyle(ParchmentTheme.Palette.slate)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(unlocked ? "✓" : "\(current)/\(threshold)")
                    .font(.parchmentRounded(size: 14, weight: .heavy).monospacedDigit())
                    .foregroundStyle(unlocked
                        ? ParchmentTheme.Palette.objectiveGreenText
                        : ParchmentTheme.Palette.ink)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ParchmentTheme.Palette.paperDust)
                        .frame(height: 10)
                    Capsule()
                        .fill(unlocked
                            ? ParchmentTheme.Palette.objectiveGreen
                            : ParchmentTheme.Palette.footerBlue)
                        .frame(width: geo.size.width * CGFloat(progress), height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(ParchmentTheme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ParchmentTheme.Palette.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            unlocked
                                ? ParchmentTheme.Palette.objectiveGreen
                                : ParchmentTheme.Palette.paperDust,
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: ParchmentTheme.Palette.ink.opacity(0.07), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    MilestonesScreen(
        milestoneTracker: MilestoneTracker(),
        onBack: {}
    )
}
