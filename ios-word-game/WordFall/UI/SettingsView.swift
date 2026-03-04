import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ParchmentBackdrop()
                .ignoresSafeArea()

            VStack(spacing: ParchmentTheme.Spacing.lg) {
                HStack {
                    Text("Settings")
                        .font(.parchmentRounded(size: 30, weight: .heavy))
                        .foregroundStyle(ParchmentTheme.Palette.ink)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(ParchmentTheme.Palette.ink)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(ParchmentTheme.Palette.white)
                                    .overlay(
                                        Circle()
                                            .stroke(ParchmentTheme.Palette.ink, lineWidth: ParchmentTheme.Stroke.hud)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, ParchmentTheme.Spacing.xl)

                VStack(spacing: ParchmentTheme.Spacing.md) {
                    settingsToggle(
                        title: "Haptics",
                        subtitle: "Tile taps and feedback buzz",
                        isOn: $settings.hapticsEnabled
                    )
                    settingsToggle(
                        title: "Sound",
                        subtitle: "Game sound effects",
                        isOn: $settings.soundEnabled
                    )
                    settingsToggle(
                        title: "Reduce Motion",
                        subtitle: "Use simpler, shorter animations",
                        isOn: $settings.reduceMotion
                    )
                    settingsToggle(
                        title: "High Contrast",
                        subtitle: "Stronger text and strokes",
                        isOn: $settings.highContrast
                    )
                }
                .padding(ParchmentTheme.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ParchmentTheme.Palette.paperBase)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(ParchmentTheme.Palette.ink.opacity(0.86), lineWidth: ParchmentTheme.Stroke.hud)
                        )
                )
                .shadow(color: ParchmentTheme.Palette.ink.opacity(0.14), radius: 8, x: 0, y: 5)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Close")
                        .font(.parchmentRounded(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                                .fill(ParchmentTheme.Palette.slate)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                                        .stroke(ParchmentTheme.Palette.ink.opacity(0.5), lineWidth: ParchmentTheme.Stroke.button)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, ParchmentTheme.Spacing.xl)
            }
            .padding(.horizontal, ParchmentTheme.Spacing.xl)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.parchmentRounded(size: 17, weight: .heavy))
                    .foregroundStyle(ParchmentTheme.Palette.ink)
                Text(subtitle)
                    .font(.parchmentRounded(size: 12, weight: .bold))
                    .foregroundStyle(ParchmentTheme.Palette.slate)
            }
        }
        .tint(ParchmentTheme.Palette.objectiveGreen)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ParchmentTheme.Palette.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ParchmentTheme.Palette.ink.opacity(0.2), lineWidth: 1.8)
                )
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore.shared)
}
