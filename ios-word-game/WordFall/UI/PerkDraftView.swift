import SwiftUI

struct PerkDraftView: View {
    private enum DraftChrome {
        static let panelWidth: CGFloat = 430
        static let panelCornerRadius: CGFloat = StitchTheme.RuunChrome.panelRadius
        static let panelBorder: CGFloat = StitchTheme.RuunChrome.panelLineWidth
        static let panelDepth: CGFloat = StitchTheme.RuunChrome.panelDepth
        static let cardCornerRadius: CGFloat = StitchTheme.RuunChrome.cardRadius
        static let cardBorder: CGFloat = StitchTheme.RuunChrome.cardLineWidth
        static let cardDepth: CGFloat = StitchTheme.RuunChrome.cardDepth
        static let cardSpacing: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let cardMinHeight: CGFloat = 172
        static let actionHeight: CGFloat = 44
    }

    let roundIndex: Int
    let options: [Perk]
    let onSelect: (PerkID) -> Void

    @State private var selectedPerkID: PerkID? = nil
    @State private var isProcessingSelection: Bool = false
    @State private var selectionFlash: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(proxy.size.width - 32, DraftChrome.panelWidth)
            let panelMaxHeight = min(proxy.size.height - 32, 760)

            ZStack {
                StitchTheme.Colors.backdrop
                    .ignoresSafeArea()

                ZStack {
                    StitchRoundedSurface(
                        fill: StitchTheme.BoardGame.canvasWarm,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.outline,
                        cornerRadius: DraftChrome.panelCornerRadius,
                        lineWidth: DraftChrome.panelBorder,
                        depth: DraftChrome.panelDepth
                    )

                    VStack(spacing: 0) {
                        headerSection

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: DraftChrome.cardSpacing) {
                                ForEach(Array(options.prefix(3)), id: \.id) { perk in
                                    perkCard(perk)
                                }
                            }
                            .padding(16)
                        }
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: DraftChrome.panelCornerRadius, style: .continuous)
                    )
                }
                .frame(width: panelWidth)
                .frame(maxHeight: panelMaxHeight)
                .padding(.bottom, DraftChrome.panelDepth)
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("ROUND \(String(format: "%02d", roundIndex)) CLEARED")
                .font(StitchTheme.Typography.labelCaps(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(StitchTheme.BoardGame.textSecondary.opacity(0.9))

            Text("ROUND CLEARED")
                .font(StitchTheme.Typography.valueHero(size: 28, weight: .black))
                .tracking(-1)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .minimumScaleFactor(0.8)

            Text("CHOOSE A PERK")
                .font(StitchTheme.Typography.labelCaps(size: 14, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(StitchTheme.BoardGame.goldStrong)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(StitchTheme.BoardGame.canvasWarm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.18))
                .frame(height: 2)
        }
    }

    private func perkCard(_ perk: Perk) -> some View {
        let rarity = perk.rarity
        let rarityColors = rarity.palette
        let isSelected = selectedPerkID == perk.id
        let shouldDim = isProcessingSelection && !isSelected

        return Button {
            selectPerk(perk.id)
        } label: {
            ZStack(alignment: .topTrailing) {
                StitchRoundedSurface(
                    fill: StitchTheme.BoardGame.surface,
                    border: isSelected ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.outline,
                    shadow: isSelected ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.outline,
                    cornerRadius: DraftChrome.cardCornerRadius,
                    lineWidth: DraftChrome.cardBorder,
                    depth: DraftChrome.cardDepth
                )

                RoundedRectangle(cornerRadius: DraftChrome.cardCornerRadius, style: .continuous)
                    .fill(StitchTheme.BoardGame.gold.opacity(isSelected && selectionFlash ? 0.12 : 0))

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        perkIconChip(perk: perk, isSelected: isSelected)

                        Spacer(minLength: 8)

                        rarityBadge(title: rarity.rawValue, colors: rarityColors)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(perk.name.uppercased())
                            .font(StitchTheme.Typography.subtitle(size: 17, weight: .black))
                            .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)

                        Text(perk.description)
                            .font(StitchTheme.Typography.body(size: 14, weight: .medium))
                            .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(1)
                    }

                    selectionBar(isSelected: isSelected)
                }
                .frame(maxWidth: .infinity, minHeight: DraftChrome.cardMinHeight, alignment: .topLeading)
                .padding(DraftChrome.cardPadding)

                if isSelected {
                    activeBadge
                        .offset(x: 10, y: -12)
                }
            }
            .padding(.bottom, DraftChrome.cardDepth)
            .opacity(shouldDim ? 0.55 : 1)
            .saturation(shouldDim ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: shouldDim)
            .animation(.easeOut(duration: 0.14), value: selectionFlash)
        }
        .buttonStyle(ParchmentPressStyle())
        .disabled(isProcessingSelection)
    }

    private func perkIconChip(perk: Perk, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                .fill(isSelected ? StitchTheme.BoardGame.gold.opacity(0.2) : StitchTheme.BoardGame.surfaceWarm)

            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)

            Image(systemName: perk.symbolName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
        }
        .frame(width: StitchTheme.RuunChrome.iconChipSize, height: StitchTheme.RuunChrome.iconChipSize)
    }

    private func rarityBadge(title: String, colors: (fill: Color, stroke: Color, text: Color)) -> some View {
        Text(title)
            .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(colors.fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(colors.stroke, lineWidth: StitchTheme.RuunChrome.secondaryCardLineWidth)
                    )
            )
    }

    private func selectionBar(isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .black))
            }

            Text(isSelected ? "SELECTED" : "SELECT")
                .font(StitchTheme.Typography.body(size: 14, weight: .heavy))
                .tracking(0.3)
        }
        .foregroundStyle(StitchTheme.BoardGame.textPrimary)
        .frame(maxWidth: .infinity, minHeight: DraftChrome.actionHeight)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.surfaceWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.buttonLineWidth)
                )
        )
    }

    private var activeBadge: some View {
        Text("ACTIVE")
            .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(StitchTheme.BoardGame.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(StitchTheme.BoardGame.gold)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)
                    )
            )
    }

    private func selectPerk(_ perkID: PerkID) {
        guard !isProcessingSelection else { return }
        isProcessingSelection = true
        selectedPerkID = perkID
        selectionFlash = false
        Haptics.selectionStep()

        withAnimation(.easeOut(duration: 0.14)) {
            selectionFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onSelect(perkID)
        }
    }
}

private extension ModifierRarity {
    var palette: (fill: Color, stroke: Color, text: Color) {
        switch self {
        case .common:
            return (
                fill: StitchTheme.BoardGame.surfaceWarm,
                stroke: StitchTheme.BoardGame.outline.opacity(0.12),
                text: StitchTheme.BoardGame.textSecondary.opacity(0.7)
            )
        case .uncommon:
            return (
                fill: ParchmentTheme.Palette.objectiveTagFill,
                stroke: ParchmentTheme.Palette.objectiveGreen.opacity(0.35),
                text: ParchmentTheme.Palette.objectiveGreenText
            )
        case .rare:
            return (
                fill: StitchTheme.BoardGame.goldWash,
                stroke: StitchTheme.BoardGame.gold,
                text: StitchTheme.BoardGame.goldStrong
            )
        case .epic:
            return (
                fill: ParchmentTheme.Palette.footerPurple.opacity(0.15),
                stroke: ParchmentTheme.Palette.footerPurpleStroke.opacity(0.5),
                text: ParchmentTheme.Palette.footerPurpleStroke
            )
        }
    }
}

private extension Modifier {
    var symbolName: String {
        switch id {
        case .lockRefund:
            return "lock.open.fill"
        case .freshSpark:
            return "sparkles"
        case .longBreaker:
            return "hammer.fill"
        case .straightShooter:
            return "scope"
        case .freeHint:
            return "lightbulb.fill"
        case .freeUndo:
            return "arrow.uturn.backward.circle.fill"
        case .rareRelief:
            return "wand.and.stars"
        case .consonantCrunch:
            return "textformat"
        case .vowelBloom:
            return "drop.fill"
        case .tightGloves:
            return "figure.run"
        case .lockSplash:
            return "bolt.fill"
        case .bigGame:
            return "crown.fill"
        case .vowelBloomPlus:
            return "chart.bar.fill"
        case .overclockedBoots:
            return "bolt.circle.fill"
        case .austerityPact:
            return "scalemass.fill"
        case .wildcardSmith:
            return "wand.and.stars"
        case .salvageRights:
            return "shippingbox.fill"
        case .bossHunter:
            return "flag.checkered"
        case .titanTribute:
            return "trophy.fill"
        case .echoChamber:
            return "square.stack.3d.up.fill"
        }
    }
}

struct PerkDraftView_Previews: PreviewProvider {
    static var previews: some View {
        PerkDraftView(
            roundIndex: 2,
            options: [
                PerkID.lockRefund.definition,
                PerkID.freshSpark.definition,
                PerkID.longBreaker.definition
            ],
            onSelect: { _ in }
        )
    }
}
