import SwiftUI

struct StartScreen: View {
    let milestoneTracker: MilestoneTracker
    let onPlay: () -> Void
    let onMilestones: () -> Void

    @State private var showSettings = false

    var body: some View {
        ZStack {
            ParchmentBackdrop()
                .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: max(32, proxy.size.height * 0.08))

                    // Title
                    VStack(spacing: ParchmentTheme.Spacing.sm) {
                        Text("WordFall")
                            .font(.parchmentRounded(size: 52, weight: .heavy))
                            .foregroundStyle(ParchmentTheme.Palette.ink)
                            .rotationEffect(.degrees(-1.5))

                        Text("Break locks. Build words.")
                            .font(.parchmentRounded(size: 15, weight: .bold))
                            .foregroundStyle(ParchmentTheme.Palette.slate)
                    }

                    Spacer(minLength: max(56, proxy.size.height * 0.14))

                    // Main play button
                    menuButton(
                        "Play Run",
                        subtitle: "15 boards · 3 acts",
                        fill: ParchmentTheme.Palette.objectiveGreen,
                        stroke: ParchmentTheme.Palette.objectiveGreenText,
                        action: onPlay
                    )

                    Spacer().frame(height: ParchmentTheme.Spacing.xl + 6)

                    // Secondary row
                    HStack(spacing: ParchmentTheme.Spacing.md) {
                        secondaryButton(
                            icon: "star.fill",
                            label: "Milestones",
                            fill: ParchmentTheme.Palette.footerYellow,
                            stroke: ParchmentTheme.Palette.footerYellowStroke,
                            action: onMilestones
                        )

                        secondaryButton(
                            icon: "gearshape.fill",
                            label: "Settings",
                            fill: ParchmentTheme.Palette.slate,
                            stroke: ParchmentTheme.Palette.ink.opacity(0.45),
                            action: { showSettings = true }
                        )
                    }

                    Spacer(minLength: max(ParchmentTheme.Spacing.xxl + 6, proxy.safeAreaInsets.bottom + 22))
                }
                .padding(.horizontal, ParchmentTheme.Spacing.xl)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(SettingsStore.shared)
        }
    }

    // MARK: - Button builders

    private func menuButton(
        _ title: String,
        subtitle: String,
        fill: Color,
        stroke: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.parchmentRounded(size: 22, weight: .heavy))
                Text(subtitle)
                    .font(.parchmentRounded(size: 12, weight: .bold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                            .stroke(stroke, lineWidth: ParchmentTheme.Stroke.button)
                    )
            )
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.button.opacity),
                radius: ParchmentTheme.Shadow.button.radius,
                x: ParchmentTheme.Shadow.button.x,
                y: ParchmentTheme.Shadow.button.y
            )
            .overlay(
                RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button - 16, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(
        icon: String,
        label: String,
        fill: Color,
        stroke: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: ParchmentTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(label)
                    .font(.parchmentRounded(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                            .stroke(stroke, lineWidth: ParchmentTheme.Stroke.button)
                    )
            )
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.button.opacity),
                radius: ParchmentTheme.Shadow.button.radius,
                x: ParchmentTheme.Shadow.button.x,
                y: ParchmentTheme.Shadow.button.y
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StartScreen(
        milestoneTracker: MilestoneTracker(),
        onPlay: {},
        onMilestones: {}
    )
}
