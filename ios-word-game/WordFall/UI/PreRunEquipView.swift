import SwiftUI

private let slotUnlockOrder: [ProfileUnlockID] = [
    .equipSlot1, .equipSlot2, .equipSlot3, .equipSlot4
]

struct PreRunEquipView: View {
    private enum EquipChrome {
        static let horizontalPadding: CGFloat = StitchTheme.RuunChrome.screenHorizontalPadding
        static let sectionSpacing: CGFloat = StitchTheme.RuunChrome.sectionSpacing
        static let cardSpacing: CGFloat = 16
        static let footerHeight: CGFloat = 114
        static let cardCornerRadius: CGFloat = StitchTheme.RuunChrome.cardRadius
    }

    let playerProfile: PlayerProfile
    let onCancel: () -> Void
    let onStart: ([StarterPerkID]) -> Void

    @State private var selectedPerks: [StarterPerkID]

    private let collectionColumns = [
        GridItem(.flexible(), spacing: EquipChrome.cardSpacing),
        GridItem(.flexible(), spacing: EquipChrome.cardSpacing)
    ]

    init(
        playerProfile: PlayerProfile,
        initialSelection: [StarterPerkID],
        onCancel: @escaping () -> Void,
        onStart: @escaping ([StarterPerkID]) -> Void
    ) {
        self.playerProfile = playerProfile
        self.onCancel = onCancel
        self.onStart = onStart
        _selectedPerks = State(initialValue: initialSelection)
    }

    private var availableSlots: Int {
        playerProfile.availableEquipSlots
    }

    private var remainingSlots: Int {
        max(availableSlots - selectedPerks.count, 0)
    }

    private var capacityProgress: CGFloat {
        guard availableSlots > 0 else { return 0 }
        return CGFloat(selectedPerks.count) / CGFloat(availableSlots)
    }

    var body: some View {
        ZStack {
            StitchTheme.BoardGame.canvasWarm
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: EquipChrome.sectionSpacing) {
                        loadoutCapacitySection
                        equippedSlotsSection
                        availablePerksSection
                    }
                    .padding(.horizontal, EquipChrome.horizontalPadding)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    footerActions
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        ZStack {
            Text("EQUIP YOUR RUN")
                .font(StitchTheme.Typography.subtitle(size: 18, weight: .heavy))
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .lineLimit(1)

            HStack {
                Button(action: onCancel) {
                    RuunHeaderControl(systemImage: "arrow.left", iconSize: 18)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Color.clear
                    .frame(
                        width: StitchTheme.RuunChrome.headerControlSize,
                        height: StitchTheme.RuunChrome.headerControlSize
                    )
            }
        }
        .padding(.horizontal, StitchTheme.RuunChrome.screenHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, StitchTheme.RuunChrome.headerBottomPadding)
        .background(StitchTheme.BoardGame.canvasWarm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.18))
                .frame(height: 2)
        }
    }

    private var loadoutCapacitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LOADOUT CAPACITY")
                        .font(StitchTheme.Typography.labelCaps(size: 12, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(StitchTheme.BoardGame.goldStrong)

                    Text(capacityTitle)
                        .font(StitchTheme.Typography.valueHero(size: 22))
                        .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                }

                Spacer(minLength: 8)

                Text(capacitySubtitle)
                    .font(StitchTheme.Typography.body(size: 14, weight: .medium))
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                    .multilineTextAlignment(.trailing)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(StitchTheme.BoardGame.surfaceMuted)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(StitchTheme.BoardGame.surfaceMutedBorder, lineWidth: 1.5)
                        )

                    Capsule(style: .continuous)
                        .fill(StitchTheme.BoardGame.gold)
                        .frame(width: max(0, (proxy.size.width - 4) * capacityProgress))
                        .padding(2)
                }
            }
            .frame(height: 16)
        }
        .padding(20)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surfaceWarm,
                border: StitchTheme.BoardGame.gold.opacity(0.18),
                shadow: StitchTheme.BoardGame.gold.opacity(0.12),
                cornerRadius: EquipChrome.cardCornerRadius,
                lineWidth: StitchTheme.RuunChrome.secondaryCardLineWidth,
                depth: 0
            )
        )
    }

    private var equippedSlotsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(title: "Equipped Perks", systemImage: "book.pages")

            LazyVGrid(columns: collectionColumns, spacing: EquipChrome.cardSpacing) {
                ForEach(0..<slotUnlockOrder.count, id: \.self) { index in
                    slotCard(slotIndex: index)
                }
            }
        }
    }

    @ViewBuilder
    private func slotCard(slotIndex: Int) -> some View {
        let isUnlocked = slotIndex < availableSlots
        let equippedPerk = slotIndex < selectedPerks.count ? selectedPerks[slotIndex] : nil
        let unlockID = slotIndex < slotUnlockOrder.count ? slotUnlockOrder[slotIndex] : nil

        if let perk = equippedPerk, isUnlocked {
            Button {
                toggle(perk)
            } label: {
                perkTile(
                    title: perk.title,
                    detail: perk.summary,
                    symbol: perk.symbolName,
                    isEquipped: true,
                    isMuted: false,
                    badgeText: "STARTER"
                )
            }
            .buttonStyle(.plain)
        } else if isUnlocked {
            emptyEquippedCard
        } else {
            lockedSlotCard(unlockID: unlockID)
        }
    }

    private var emptyEquippedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            leadingIconChip(
                systemImage: "plus.circle",
                tint: StitchTheme.BoardGame.goldStrong,
                fill: StitchTheme.BoardGame.goldWash
            )

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("Empty Slot")
                    .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)

                Text("Select a starter perk below.")
                    .font(StitchTheme.Typography.caption(size: 11, weight: .medium))
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(18)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surface,
                border: StitchTheme.BoardGame.gold.opacity(0.7),
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: EquipChrome.cardCornerRadius,
                lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                depth: StitchTheme.RuunChrome.cardDepth,
                dash: [5, 4]
            )
        )
        .padding(.bottom, StitchTheme.RuunChrome.cardDepth)
    }

    private func lockedSlotCard(unlockID: ProfileUnlockID?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            leadingIconChip(
                systemImage: "lock.fill",
                tint: StitchTheme.BoardGame.textMuted,
                fill: StitchTheme.BoardGame.surfaceMuted.opacity(0.55)
            )

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(unlockID?.title ?? "Locked Slot")
                    .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)

                Text("Unlock at \(unlockID?.threshold ?? 0) XP")
                    .font(StitchTheme.Typography.caption(size: 11, weight: .medium))
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(18)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surface,
                border: StitchTheme.BoardGame.surfaceMutedBorder,
                shadow: StitchTheme.BoardGame.surfaceMutedBorder,
                cornerRadius: EquipChrome.cardCornerRadius,
                lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                depth: StitchTheme.RuunChrome.cardDepth
            )
        )
        .padding(.bottom, StitchTheme.RuunChrome.cardDepth)
        .opacity(0.65)
    }

    private var availablePerksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(title: "Available Collection", systemImage: "shippingbox")

            LazyVGrid(columns: collectionColumns, spacing: EquipChrome.cardSpacing) {
                ForEach(StarterPerkID.allCases) { perk in
                    availablePerkCard(perk)
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func availablePerkCard(_ perk: StarterPerkID) -> some View {
        let isSelected = selectedPerks.contains(perk)
        let isSelectable = isSelected || selectedPerks.count < availableSlots

        return Button {
            toggle(perk)
        } label: {
            perkTile(
                title: perk.title,
                detail: perk.summary,
                symbol: perk.symbolName,
                isEquipped: isSelected,
                isMuted: !isSelectable,
                badgeText: isSelected ? "EQUIPPED" : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
        .opacity(isSelectable ? 1 : 0.6)
    }

    private func perkTile(
        title: String,
        detail: String,
        symbol: String,
        isEquipped: Bool,
        isMuted: Bool,
        badgeText: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                leadingIconChip(
                    systemImage: symbol,
                    tint: isMuted ? StitchTheme.BoardGame.textMuted : StitchTheme.BoardGame.goldStrong,
                    fill: isEquipped ? StitchTheme.BoardGame.goldWash : StitchTheme.BoardGame.surfaceWarm
                )

                Spacer(minLength: 8)

                if let badgeText {
                    Text(badgeText)
                        .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(StitchTheme.BoardGame.gold)
                        )
                }
            }

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                    .foregroundStyle(isMuted ? StitchTheme.BoardGame.textSecondary : StitchTheme.BoardGame.textPrimary)

                Text(detail)
                    .font(StitchTheme.Typography.caption(size: 11, weight: .medium))
                    .foregroundStyle(isMuted ? StitchTheme.BoardGame.textMuted : StitchTheme.BoardGame.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(18)
        .background {
            ZStack {
                StitchRoundedSurface(
                    fill: StitchTheme.BoardGame.surface,
                    border: isEquipped ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.surfaceMutedBorder,
                    shadow: isEquipped ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.surfaceMutedBorder,
                    cornerRadius: EquipChrome.cardCornerRadius,
                    lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                    depth: StitchTheme.RuunChrome.cardDepth
                )

                if isEquipped {
                    StitchDotPattern(color: StitchTheme.BoardGame.gold.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: EquipChrome.cardCornerRadius, style: .continuous))
                }
            }
        }
        .padding(.bottom, StitchTheme.RuunChrome.cardDepth)
    }

    private var footerActions: some View {
        HStack(spacing: 16) {
            Button(action: onCancel) {
                Text("CANCEL")
                    .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: StitchTheme.RuunChrome.buttonHeight)
                    .background(
                        StitchRoundedSurface(
                            fill: StitchTheme.BoardGame.surface,
                            border: StitchTheme.BoardGame.outline,
                            shadow: StitchTheme.BoardGame.outline,
                            cornerRadius: StitchTheme.RuunChrome.buttonRadius,
                            lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                            depth: StitchTheme.RuunChrome.buttonDepth
                        )
                    )
                    .padding(.bottom, StitchTheme.RuunChrome.buttonDepth)
            }
            .buttonStyle(.plain)

            Button(action: { onStart(selectedPerks) }) {
                HStack(spacing: 8) {
                    Text("START RUN")
                        .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .black))
                }
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: StitchTheme.RuunChrome.buttonHeight)
                .background(
                    StitchRoundedSurface(
                        fill: StitchTheme.BoardGame.gold,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.goldStrong,
                        cornerRadius: StitchTheme.RuunChrome.buttonRadius,
                        lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                        depth: StitchTheme.RuunChrome.buttonDepth
                    )
                )
                .padding(.bottom, StitchTheme.RuunChrome.buttonDepth)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, EquipChrome.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(StitchTheme.BoardGame.canvasWarm.opacity(0.98))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(StitchTheme.BoardGame.outline.opacity(0.18))
                .frame(height: 2)
        }
    }

    private func sectionHeading(title: String, systemImage: String) -> some View {
        RuunSectionHeading(
            title: title,
            symbol: systemImage,
            iconColor: StitchTheme.BoardGame.goldStrong
        )
    }

    private var capacityTitle: String {
        guard availableSlots > 0 else { return "No Slots Unlocked" }
        return "\(selectedPerks.count) of \(availableSlots) Slots"
    }

    private var capacitySubtitle: String {
        guard availableSlots > 0 else {
            if let unlock = slotUnlockOrder.first {
                return "Unlock at \(unlock.threshold) XP"
            }
            return "No slots available"
        }

        if remainingSlots == 0 {
            return "Loadout full"
        }

        if remainingSlots == 1 {
            return "1 slot remaining"
        }

        return "\(remainingSlots) slots remaining"
    }

    private func toggle(_ perk: StarterPerkID) {
        if let index = selectedPerks.firstIndex(of: perk) {
            if AppSettings.reduceMotion {
                selectedPerks.remove(at: index)
            } else {
                _ = withAnimation(.easeOut(duration: 0.15)) {
                    selectedPerks.remove(at: index)
                }
            }
            return
        }

        guard selectedPerks.count < availableSlots else { return }
        if AppSettings.reduceMotion {
            selectedPerks.append(perk)
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedPerks.append(perk)
            }
        }
    }

    private func leadingIconChip(systemImage: String, tint: Color, fill: Color) -> some View {
        RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
            .fill(fill)
            .frame(
                width: StitchTheme.RuunChrome.iconChipSize,
                height: StitchTheme.RuunChrome.iconChipSize
            )
            .overlay {
                RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                    .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)
            }
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(tint)
            }
    }
}

private extension StarterPerkID {
    var symbolName: String {
        switch self {
        case .pencilGrip:
            return "pencil.tip"
        case .cleanInk:
            return "drop.fill"
        case .spareSeal:
            return "lock.shield"
        }
    }
}

struct PreRunEquipView_Previews: PreviewProvider {
    static var previews: some View {
        PreRunEquipView(
            playerProfile: PlayerProfile(),
            initialSelection: [],
            onCancel: {},
            onStart: { _ in }
        )
    }
}
