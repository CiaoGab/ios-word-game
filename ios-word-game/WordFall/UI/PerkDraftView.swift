import SwiftUI

struct PerkDraftView: View {
    let boardIndex: Int
    let options: [Perk]
    let onSelect: (PerkID) -> Void

    @State private var selectedPerkID: PerkID? = nil
    @State private var isProcessingSelection: Bool = false
    @State private var selectionFlash: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: ParchmentTheme.Spacing.xl) {
                VStack(spacing: ParchmentTheme.Spacing.xs) {
                    Text("Board \(boardIndex) Cleared")
                        .font(.parchmentRounded(size: 29, weight: .heavy))
                        .foregroundStyle(ParchmentTheme.Palette.objectiveGreenText)
                    Text("Pick a modifier to carry forward")
                        .font(.parchmentRounded(size: 15, weight: .bold))
                        .foregroundStyle(ParchmentTheme.Palette.slate)
                }

                VStack(spacing: ParchmentOverlayStyle.Tunables.cardSpacing) {
                    ForEach(Array(options.prefix(3).enumerated()), id: \.element.id) { index, perk in
                        perkCard(perk)
                            .rotationEffect(.degrees(cardTilt(index)))
                    }
                }
            }
            .padding(ParchmentTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.panel, style: .continuous)
                    .fill(ParchmentTheme.Palette.paperBase)
                    .overlay(
                        RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.panel, style: .continuous)
                            .stroke(ParchmentTheme.Palette.ink.opacity(0.88), lineWidth: ParchmentOverlayStyle.Stroke.panel)
                    )
            )
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(0.18),
                radius: ParchmentOverlayStyle.Tunables.panelShadowRadius,
                x: 0,
                y: ParchmentOverlayStyle.Tunables.panelShadowY
            )
            .padding(.horizontal, ParchmentTheme.Spacing.xl)
        }
    }

    private func perkCard(_ perk: Perk) -> some View {
        let rarity = rarity(for: perk.id)
        let rarityColors = rarity.palette
        let isSelected = selectedPerkID == perk.id
        let shouldDim = isProcessingSelection && !isSelected

        return Button {
            selectPerk(perk.id)
        } label: {
            VStack(alignment: .leading, spacing: ParchmentTheme.Spacing.xs) {
                HStack(alignment: .top, spacing: ParchmentTheme.Spacing.sm) {
                    Text(perk.name)
                        .font(.parchmentRounded(size: 22, weight: .heavy))
                        .foregroundStyle(ParchmentTheme.Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 8)

                    Text(rarity.rawValue)
                        .font(.parchmentRounded(size: 11, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(rarityColors.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(rarityColors.fill)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(rarityColors.stroke, lineWidth: ParchmentOverlayStyle.Stroke.chip)
                                )
                        )
                }

                Text(perk.description)
                    .font(.parchmentRounded(size: 14, weight: .bold))
                    .foregroundStyle(ParchmentTheme.Palette.slate)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if let tradeoff = perk.tradeoff {
                    Text("Tradeoff: \(tradeoff)")
                        .font(.parchmentRounded(size: 12, weight: .bold))
                        .foregroundStyle(ParchmentTheme.Palette.footerRedStroke)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ParchmentTheme.Spacing.lg)
            .padding(.vertical, ParchmentTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.card, style: .continuous)
                    .fill(ParchmentTheme.Palette.paperDust.opacity(0.42))
                    .offset(y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.card, style: .continuous)
                            .fill(ParchmentTheme.Palette.white.opacity(0.96))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.card, style: .continuous)
                            .stroke(
                                isSelected ? ParchmentTheme.Palette.objectiveGreenText : ParchmentTheme.Palette.ink.opacity(0.85),
                                lineWidth: ParchmentOverlayStyle.Stroke.card
                            )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: ParchmentOverlayStyle.Radius.card, style: .continuous)
                    .fill(ParchmentTheme.Palette.objectiveGreen.opacity(isSelected && selectionFlash ? 0.22 : 0))
            }
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(0.12),
                radius: ParchmentOverlayStyle.Tunables.cardShadowRadius,
                x: 0,
                y: ParchmentOverlayStyle.Tunables.cardShadowY
            )
            .opacity(shouldDim ? 0.55 : 1)
            .saturation(shouldDim ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: shouldDim)
            .animation(.easeOut(duration: ParchmentOverlayStyle.Tunables.cardSelectionFlashDuration), value: selectionFlash)
        }
        .buttonStyle(ParchmentPressStyle())
        .disabled(isProcessingSelection)
    }

    private func cardTilt(_ index: Int) -> Double {
        switch index {
        case 0: return -0.8
        case 1: return 0.6
        case 2: return -0.4
        default: return 0
        }
    }

    private func selectPerk(_ perkID: PerkID) {
        guard !isProcessingSelection else { return }
        isProcessingSelection = true
        selectedPerkID = perkID
        selectionFlash = false
        Haptics.selectionStep()

        withAnimation(.easeOut(duration: ParchmentOverlayStyle.Tunables.cardSelectionFlashDuration)) {
            selectionFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + ParchmentOverlayStyle.Tunables.cardSelectionCommitDelay) {
            onSelect(perkID)
        }
    }

    private func rarity(for perkID: PerkID) -> PerkRarity {
        switch perkID {
        case .freeHint, .freeUndo, .vowelBloom:
            return .common
        case .freshSpark, .straightShooter, .consonantCrunch, .tightGloves, .lockSplash:
            return .uncommon
        case .lockRefund, .longBreaker, .rareRelief, .bigGame, .vowelBloomPlus:
            return .rare
        }
    }
}

private enum PerkRarity: String {
    case common = "COMMON"
    case uncommon = "UNCOMMON"
    case rare = "RARE"

    var palette: (fill: Color, stroke: Color, text: Color) {
        switch self {
        case .common:
            return (
                fill: ParchmentTheme.Palette.footerBlue.opacity(0.16),
                stroke: ParchmentTheme.Palette.footerBlueStroke.opacity(0.7),
                text: ParchmentTheme.Palette.footerBlueStroke
            )
        case .uncommon:
            return (
                fill: ParchmentTheme.Palette.objectiveTagFill,
                stroke: ParchmentTheme.Palette.objectiveGreen.opacity(0.8),
                text: ParchmentTheme.Palette.objectiveGreenText
            )
        case .rare:
            return (
                fill: ParchmentTheme.Palette.levelYellow.opacity(0.72),
                stroke: ParchmentTheme.Palette.footerYellowStroke.opacity(0.85),
                text: ParchmentTheme.Palette.footerYellowStroke
            )
        }
    }
}

#Preview {
    PerkDraftView(
        boardIndex: 2,
        options: [
            PerkID.lockRefund.definition,
            PerkID.freshSpark.definition,
            PerkID.longBreaker.definition
        ],
        onSelect: { _ in }
    )
}
