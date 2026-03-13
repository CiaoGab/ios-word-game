import SwiftUI

enum RuunSettingsChrome {
    static let horizontalPadding: CGFloat = StitchTheme.RuunChrome.screenHorizontalPadding
    static let sectionSpacing: CGFloat = StitchTheme.RuunChrome.sectionSpacing
    static let panelCornerRadius: CGFloat = StitchTheme.RuunChrome.cardRadius
    static let panelDepth: CGFloat = StitchTheme.RuunChrome.cardDepth
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 16
    static let rowSpacing: CGFloat = 16
    static let dividerLeading: CGFloat = 66
    static let dividerTrailing: CGFloat = 16
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let playerProfile: PlayerProfile?

    init(playerProfile: PlayerProfile? = nil) {
        self.playerProfile = playerProfile
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = max(16, proxy.safeAreaInsets.top + 8)
            let bottomInset = max(28, proxy.safeAreaInsets.bottom + 12)

            ZStack {
                StitchTheme.BoardGame.canvasWarm
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topInset: topInset)

                    ScrollView(showsIndicators: false) {
                        RuunSettingsContent(
                            playerProfile: playerProfile,
                            bottomPadding: bottomInset
                        )
                        .padding(.horizontal, RuunSettingsChrome.horizontalPadding)
                        .padding(.top, 24)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private func header(topInset: CGFloat) -> some View {
        ZStack {
            Text("SETTINGS")
                .font(StitchTheme.Typography.subtitle(size: 20, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)

            HStack {
                Color.clear
                    .frame(
                        width: StitchTheme.RuunChrome.headerControlSize,
                        height: StitchTheme.RuunChrome.headerControlSize
                    )

                Spacer()

                Button(action: { dismiss() }) {
                    RuunHeaderControl(systemImage: "xmark", iconSize: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, RuunSettingsChrome.horizontalPadding)
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

struct RuunSettingsContent: View {
    let playerProfile: PlayerProfile?
    var bottomPadding: CGFloat = 0

    @ObservedObject private var settings = SettingsStore.shared
    @AppStorage("settings.musicEnabled") private var musicEnabled = true
    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = false
    @State private var showResetProfileConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: RuunSettingsChrome.sectionSpacing) {
            audioSection
            accessibilitySection
            #if DEBUG
            debugSection
            #endif
            accountSection
            RuunSettingsFooterBrandmark()
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, bottomPadding)
        }
        .alert("Reset XP Profile?", isPresented: $showResetProfileConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                playerProfile?.reset()
            }
        } message: {
            Text("This clears total XP, lifetime XP stats, and XP-based unlocks.")
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            RuunSettingsSectionHeading(
                title: "Audio & Feedback",
                symbol: "speaker.wave.2.fill"
            )

            RuunSettingsPanel {
                VStack(spacing: 0) {
                    RuunSettingsToggleRow(
                        title: "Sound FX",
                        subtitle: "Game sound effects",
                        systemImage: "speaker.wave.2.fill",
                        iconTint: StitchTheme.BoardGame.goldStrong,
                        isOn: $settings.soundEnabled
                    )
                    RuunSettingsDivider()
                    RuunSettingsToggleRow(
                        title: "Music",
                        subtitle: "Menu and run music",
                        systemImage: "music.note",
                        iconTint: StitchTheme.BoardGame.goldStrong,
                        isOn: $musicEnabled
                    )
                    RuunSettingsDivider()
                    RuunSettingsToggleRow(
                        title: "Haptics",
                        subtitle: "Tile taps and feedback buzz",
                        systemImage: "iphone.radiowaves.left.and.right",
                        iconTint: StitchTheme.BoardGame.goldStrong,
                        isOn: $settings.hapticsEnabled
                    )
                }
            }
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            RuunSettingsSectionHeading(
                title: "Display & Accessibility",
                symbol: "circle.lefthalf.filled"
            )

            RuunSettingsPanel {
                VStack(spacing: 0) {
                    RuunSettingsToggleRow(
                        title: "Reduce Motion",
                        subtitle: "Use simpler, shorter animations",
                        systemImage: "figure.walk.motion",
                        iconTint: StitchTheme.BoardGame.goldStrong,
                        isOn: $settings.reduceMotion
                    )
                    RuunSettingsDivider()
                    RuunSettingsToggleRow(
                        title: "High Contrast",
                        subtitle: "Stronger text and strokes",
                        systemImage: "circle.lefthalf.filled",
                        iconTint: StitchTheme.BoardGame.goldStrong,
                        isOn: $settings.highContrast
                    )
                }
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            RuunSettingsSectionHeading(
                title: "Debug Menu",
                symbol: "ladybug.fill"
            )

            VStack(alignment: .leading, spacing: 10) {
                RuunSettingsPanel {
                    VStack(spacing: 0) {
                        RuunSettingsStepperRow(
                            title: "Debug Start Round",
                            subtitle: debugStartRoundSubtitle,
                            systemImage: "arrow.forward.to.line.circle",
                            iconTint: StitchTheme.BoardGame.goldStrong,
                            value: $settings.debugStartRound,
                            range: 1...RunState.Tunables.totalRounds
                        )
                    }
                }

                Text("Applies to the next new run or restart.")
                    .font(StitchTheme.Typography.labelCaps(size: 11, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)
                    .padding(.horizontal, 2)
            }
        }
    }
    #endif

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            RuunSettingsSectionHeading(
                title: "Account",
                symbol: "person.crop.circle"
            )

            RuunSettingsPanel {
                VStack(spacing: 0) {
                    RuunSettingsToggleRow(
                        title: "Notifications",
                        subtitle: "Coming soon",
                        systemImage: "bell.fill",
                        iconTint: StitchTheme.BoardGame.goldStrong,
                        isOn: $notificationsEnabled
                    )

                    if playerProfile != nil {
                        RuunSettingsDivider()
                        Button {
                            showResetProfileConfirmation = true
                        } label: {
                            RuunSettingsInfoRow(
                                title: "Reset XP Profile",
                                subtitle: "Clear XP totals and XP-based unlocks",
                                titleColor: Color(hex: 0xC63A32),
                                systemImage: "arrow.counterclockwise",
                                iconTint: Color(hex: 0xC63A32),
                                iconFill: Color(hex: 0xF6DCDD),
                                accessory: .warning
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    RuunSettingsDivider()
                    RuunSettingsInfoRow(
                        title: "Version & Credits",
                        subtitle: "RUUN v\(appVersion) • JV Studio",
                        systemImage: "info.circle",
                        iconTint: StitchTheme.BoardGame.goldStrong,
                        accessory: .chevron
                    )
                }
            }
        }
    }

    #if DEBUG
    private var debugStartRoundSubtitle: String {
        if settings.debugStartRound <= 1 {
            return "Round 1 starts a normal run"
        }
        return "Begin the next run at round \(settings.debugStartRound)"
    }
    #endif

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct RuunSettingsSectionHeading: View {
    let title: String
    let symbol: String

    var body: some View {
        RuunSectionHeading(title: title, symbol: symbol)
    }
}

struct RuunSettingsPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                StitchRoundedSurface(
                    fill: StitchTheme.BoardGame.surface,
                    border: StitchTheme.BoardGame.outline,
                    shadow: StitchTheme.BoardGame.outline,
                    cornerRadius: RuunSettingsChrome.panelCornerRadius,
                    lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                    depth: RuunSettingsChrome.panelDepth
                )
            )
            .padding(.bottom, RuunSettingsChrome.panelDepth)
    }
}

struct RuunSettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let iconTint: Color
    var iconFill: Color = StitchTheme.BoardGame.goldWash
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            RuunSettingsRowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconTint: iconTint,
                iconFill: iconFill
            )
        }
        .toggleStyle(RuunSettingsToggleStyle())
        .padding(.horizontal, RuunSettingsChrome.rowHorizontalPadding)
        .padding(.vertical, RuunSettingsChrome.rowVerticalPadding)
    }
}

struct RuunSettingsStepperRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let iconTint: Color
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            RuunSettingsRowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconTint: iconTint
            )
        }
        .tint(StitchTheme.BoardGame.goldStrong)
        .padding(.horizontal, RuunSettingsChrome.rowHorizontalPadding)
        .padding(.vertical, RuunSettingsChrome.rowVerticalPadding)
    }
}

struct RuunSettingsRowLabel: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let iconTint: Color
    var iconFill: Color = StitchTheme.BoardGame.goldWash
    var titleColor: Color = StitchTheme.BoardGame.textPrimary

    var body: some View {
        HStack(spacing: RuunSettingsChrome.rowSpacing) {
            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                .fill(iconFill)
                .frame(width: StitchTheme.RuunChrome.iconChipSize, height: StitchTheme.RuunChrome.iconChipSize)
                .overlay {
                    RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                        .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)
                }
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(iconTint)
                }

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                    .foregroundStyle(titleColor)

                if let subtitle {
                    Text(subtitle)
                        .font(StitchTheme.Typography.caption(size: 12, weight: .semibold))
                        .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                }
            }
        }
    }
}

struct RuunSettingsInfoRow: View {
    enum Accessory {
        case chevron
        case warning
    }

    let title: String
    let subtitle: String
    var titleColor: Color = StitchTheme.BoardGame.textPrimary
    let systemImage: String
    let iconTint: Color
    var iconFill: Color = StitchTheme.BoardGame.goldWash
    let accessory: Accessory

    var body: some View {
        HStack(spacing: RuunSettingsChrome.rowSpacing) {
            RuunSettingsRowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconTint: iconTint,
                iconFill: iconFill,
                titleColor: titleColor
            )

            Spacer(minLength: 12)

            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)
            case .warning:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)
            }
        }
        .padding(.horizontal, RuunSettingsChrome.rowHorizontalPadding)
        .padding(.vertical, RuunSettingsChrome.rowVerticalPadding)
    }
}

struct RuunSettingsFooterBrandmark: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("RUUN")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(StitchTheme.BoardGame.textMuted.opacity(0.75))

            Capsule(style: .continuous)
                .fill(StitchTheme.BoardGame.gold.opacity(0.55))
                .frame(width: 48, height: 4)
        }
        .padding(.top, 16)
        .opacity(0.9)
    }
}

struct RuunSettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(StitchTheme.BoardGame.surfaceMutedBorder.opacity(0.55))
            .frame(height: 2)
            .padding(.leading, RuunSettingsChrome.dividerLeading)
            .padding(.trailing, RuunSettingsChrome.dividerTrailing)
    }
}

struct RuunSettingsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 16) {
            configuration.label
            Spacer(minLength: 12)

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(configuration.isOn ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.surfaceMuted)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(StitchTheme.BoardGame.outline, lineWidth: 2.2)
                    )

                Circle()
                    .fill(StitchTheme.BoardGame.surface)
                    .overlay(
                        Circle()
                            .stroke(StitchTheme.BoardGame.outline, lineWidth: 2.2)
                    )
                    .padding(4)
            }
            .frame(width: 56, height: 34)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.16)) {
                configuration.isOn.toggle()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(playerProfile: PlayerProfile())
    }
}
