import SwiftUI

struct RunSummaryView: View {
    private enum SummaryChrome {
        static let panelWidth: CGFloat = 430
        static let panelCornerRadius: CGFloat = StitchTheme.RuunChrome.panelRadius
        static let panelBorder: CGFloat = StitchTheme.RuunChrome.panelLineWidth
        static let panelDepth: CGFloat = StitchTheme.RuunChrome.panelDepth
        static let cardRadius: CGFloat = StitchTheme.RuunChrome.cardRadius
        static let secondaryRadius: CGFloat = StitchTheme.RuunChrome.secondaryCardRadius
        static let depthLarge: CGFloat = StitchTheme.RuunChrome.panelDepth
        static let depthSmall: CGFloat = StitchTheme.RuunChrome.cardDepth
    }

    private struct BreakdownItem: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let symbol: String
        let accent: Bool
    }

    let snapshot: RunSummarySnapshot
    let onBackToMenu: () -> Void
    let onPlayAgain: () -> Void

    @State private var shareErrorMessage: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let topInset = max(12, proxy.safeAreaInsets.top + 4)
                let bottomInset = max(12, proxy.safeAreaInsets.bottom + 4)

                ZStack {
                    StitchRoundedSurface(
                        fill: StitchTheme.BoardGame.canvasWarm,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.outline,
                        cornerRadius: SummaryChrome.panelCornerRadius,
                        lineWidth: SummaryChrome.panelBorder,
                        depth: SummaryChrome.panelDepth
                    )

                    VStack(spacing: 0) {
                        headerSection
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: StitchTheme.RuunChrome.sectionSpacing) {
                                resultBanner
                                primaryStatsSection
                                breakdownSection
                                if !snapshot.newUnlocks.isEmpty {
                                    unlocksSection
                                }
                                buttonsSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, bottomInset + 12)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: SummaryChrome.panelCornerRadius, style: .continuous))
                }
                .frame(maxWidth: SummaryChrome.panelWidth)
                .frame(maxHeight: min(proxy.size.height - 24, 860))
                .padding(.bottom, SummaryChrome.panelDepth)
                .padding(.horizontal, 12)
                .padding(.top, topInset)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Share Run", isPresented: Binding(
            get: { shareErrorMessage != nil },
            set: { if !$0 { shareErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "")
        }
    }

    private var headerSection: some View {
        ZStack {
            Text("RUN SUMMARY")
                .font(StitchTheme.Typography.subtitle(size: 20, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)

            HStack {
                Button(action: onBackToMenu) {
                    RuunHeaderControl(systemImage: "xmark", iconSize: 14)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
                .accessibilityLabel("Close summary")

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

    private var resultBanner: some View {
        VStack(spacing: 6) {
            Text(snapshot.wonRun ? "VICTORY" : "RUN OVER")
                .font(StitchTheme.Typography.valueHero(size: 34, weight: .black))
                .tracking(-1.6)
                .foregroundStyle(snapshot.wonRun ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textPrimary)

            Text(snapshot.wonRun ? "RUN COMPLETE" : "RUN ENDED")
                .font(StitchTheme.Typography.labelCaps(size: 13, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(snapshot.wonRun ? StitchTheme.BoardGame.goldStrong.opacity(0.82) : StitchTheme.BoardGame.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 108)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: SummaryChrome.cardRadius, style: .continuous)
                .fill(snapshot.wonRun ? StitchTheme.BoardGame.goldWash : StitchTheme.BoardGame.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: SummaryChrome.cardRadius, style: .continuous)
                        .stroke(
                            snapshot.wonRun ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.outline.opacity(0.18),
                            style: StrokeStyle(lineWidth: snapshot.wonRun ? SummaryChrome.panelBorder : StitchTheme.RuunChrome.secondaryCardLineWidth)
                        )
                )
        )
    }

    private var primaryStatsSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text("FINAL SCORE")
                    .font(StitchTheme.Typography.labelCaps(size: 12, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)

                Text(snapshot.totalScore.formatted())
                    .font(StitchTheme.Typography.valueHero(size: 44, weight: .black).monospacedDigit())
                    .foregroundStyle(StitchTheme.BoardGame.goldStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                summaryChip("PROFILE XP \(snapshot.totalXPAfterRun.formatted())")
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding(.horizontal, 20)
            .padding(.vertical, 26)
            .background(
                StitchRoundedSurface(
                    fill: StitchTheme.BoardGame.surface,
                    border: StitchTheme.BoardGame.outline,
                    shadow: StitchTheme.BoardGame.outline,
                    cornerRadius: SummaryChrome.cardRadius,
                    lineWidth: StitchTheme.RuunChrome.panelLineWidth,
                    depth: SummaryChrome.depthLarge
                )
            )
            .padding(.bottom, SummaryChrome.depthLarge)

            HStack(spacing: 16) {
                primaryStatCard(
                    label: "ROUNDS CLEARED",
                    value: snapshot.roundsProgressText,
                    detail: snapshot.wonRun ? "RUN CLEARED" : "R\(snapshot.roundReached) REACHED",
                    highlight: false
                )

                primaryStatCard(
                    label: "XP EARNED",
                    value: "+\(snapshot.xpEarned.formatted())",
                    detail: snapshot.newUnlocks.isEmpty ? "PROFILE GAIN" : "UNLOCK READY",
                    highlight: true
                )
            }
        }
    }

    private func primaryStatCard(
        label: String,
        value: String,
        detail: String,
        highlight: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(StitchTheme.Typography.labelCaps(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(highlight ? StitchTheme.BoardGame.textPrimary.opacity(0.68) : StitchTheme.BoardGame.textSecondary)

            Text(value)
                .font(StitchTheme.Typography.subtitle(size: 28, weight: .black).monospacedDigit())
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(detail)
                .font(StitchTheme.Typography.caption(size: 11, weight: .heavy))
                .foregroundStyle(highlight ? StitchTheme.BoardGame.textPrimary.opacity(0.74) : StitchTheme.BoardGame.goldStrong)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(16)
        .background(
            StitchRoundedSurface(
                fill: highlight ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.surface,
                border: StitchTheme.BoardGame.outline,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: SummaryChrome.cardRadius,
                lineWidth: StitchTheme.RuunChrome.cardLineWidth,
                depth: SummaryChrome.depthSmall
            )
        )
        .padding(.bottom, SummaryChrome.depthSmall)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(title: "Run Breakdown", symbol: "chart.bar.fill")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(breakdownItems) { item in
                    breakdownTile(item)
                }
            }

            bestWordTile
        }
    }

    private var breakdownItems: [BreakdownItem] {
        var items: [BreakdownItem] = [
            BreakdownItem(
                title: "Locks Broken",
                value: snapshot.locksBroken.formatted(),
                symbol: "lock.open.fill",
                accent: false
            ),
            BreakdownItem(
                title: "Words Built",
                value: snapshot.wordsBuilt.formatted(),
                symbol: "textformat.abc",
                accent: false
            ),
            BreakdownItem(
                title: "Challenge Clears",
                value: String(format: "%02d", max(0, snapshot.challengeRoundsCleared)),
                symbol: "flag.checkered",
                accent: false
            ),
            BreakdownItem(
                title: "Rare Letter Word",
                value: snapshot.rareLetterWordUsed ? "YES" : "NO",
                symbol: "sparkles",
                accent: snapshot.rareLetterWordUsed
            )
        ]

        if !snapshot.wonRun {
            items.append(
                BreakdownItem(
                    title: "Round Reached",
                    value: "R\(snapshot.roundReached)",
                    symbol: "arrow.up.forward.square.fill",
                    accent: false
                )
            )
        }

        return items
    }

    private func breakdownTile(_ item: BreakdownItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                .fill(item.accent ? StitchTheme.BoardGame.goldWash : StitchTheme.BoardGame.surfaceMuted.opacity(0.58))
                .frame(width: StitchTheme.RuunChrome.iconChipSize, height: StitchTheme.RuunChrome.iconChipSize)
                .overlay {
                    RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                        .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)
                }
                .overlay {
                    Image(systemName: item.symbol)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(item.accent ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textSecondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.uppercased())
                    .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)
                    .lineLimit(2)

                Text(item.value)
                    .font(StitchTheme.Typography.body(size: 18, weight: .black).monospacedDigit())
                    .foregroundStyle(item.accent ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: SummaryChrome.secondaryRadius, style: .continuous)
                .fill(StitchTheme.BoardGame.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: SummaryChrome.secondaryRadius, style: .continuous)
                        .stroke(StitchTheme.BoardGame.outline.opacity(0.18), lineWidth: StitchTheme.RuunChrome.secondaryCardLineWidth)
                )
        )
    }

    private var bestWordTile: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                .fill(StitchTheme.BoardGame.goldWash)
                .frame(width: StitchTheme.RuunChrome.iconChipSize, height: StitchTheme.RuunChrome.iconChipSize)
                .overlay {
                    RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                        .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)
                }
                .overlay {
                    Image(systemName: "link")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(StitchTheme.BoardGame.goldStrong)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("BEST WORD")
                    .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)

                Text(bestWordLabel)
                    .font(StitchTheme.Typography.body(size: 20, weight: .black))
                    .tracking(bestWordLabel == "—" ? 0 : 1.2)
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text("VALUE")
                    .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textMuted)

                Text(snapshot.bestWordScore > 0 ? snapshot.bestWordScore.formatted() : "—")
                    .font(StitchTheme.Typography.body(size: 20, weight: .black).monospacedDigit())
                    .foregroundStyle(StitchTheme.BoardGame.goldStrong)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: SummaryChrome.secondaryRadius, style: .continuous)
                .fill(StitchTheme.BoardGame.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: SummaryChrome.secondaryRadius, style: .continuous)
                        .stroke(StitchTheme.BoardGame.outline.opacity(0.18), lineWidth: StitchTheme.RuunChrome.secondaryCardLineWidth)
                )
        )
    }

    private var unlocksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading(title: "New Unlocks", symbol: "sparkles.rectangle.stack.fill")

            VStack(spacing: 12) {
                ForEach(snapshot.newUnlocks, id: \.self) { unlock in
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                            .fill(StitchTheme.BoardGame.gold)
                            .frame(width: 48, height: 48)
                            .overlay {
                                RoundedRectangle(cornerRadius: StitchTheme.RuunChrome.iconChipRadius, style: .continuous)
                                    .stroke(StitchTheme.BoardGame.outline, lineWidth: StitchTheme.RuunChrome.iconChipLineWidth)
                            }
                            .overlay {
                                Image(systemName: unlockSymbol(unlock))
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(unlock.title)
                                .font(StitchTheme.Typography.body(size: 15, weight: .heavy))
                                .foregroundStyle(StitchTheme.BoardGame.textPrimary)

                            Text("\(unlock.phaseLabel.uppercased()) · \(unlock.threshold.formatted()) XP")
                                .font(StitchTheme.Typography.caption(size: 12, weight: .semibold))
                                .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: SummaryChrome.secondaryRadius, style: .continuous)
                            .fill(StitchTheme.BoardGame.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: SummaryChrome.secondaryRadius, style: .continuous)
                                    .stroke(StitchTheme.BoardGame.outline.opacity(0.18), lineWidth: StitchTheme.RuunChrome.secondaryCardLineWidth)
                            )
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: SummaryChrome.cardRadius, style: .continuous)
                .fill(StitchTheme.BoardGame.surfaceWarm)
                .overlay(
                    RoundedRectangle(cornerRadius: SummaryChrome.cardRadius, style: .continuous)
                        .stroke(
                            StitchTheme.BoardGame.gold.opacity(0.7),
                            style: StrokeStyle(lineWidth: StitchTheme.RuunChrome.secondaryCardLineWidth, dash: [5, 4])
                        )
                )
        )
    }

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            Button(action: onPlayAgain) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .black))
                    Text("PLAY AGAIN")
                        .font(StitchTheme.Typography.subtitle(size: 18, weight: .black))
                        .tracking(0.9)
                }
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: StitchTheme.RuunChrome.buttonHeight)
                .background(
                    StitchRoundedSurface(
                        fill: StitchTheme.BoardGame.gold,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.goldStrong,
                        cornerRadius: SummaryChrome.cardRadius,
                        lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                        depth: SummaryChrome.depthSmall
                    )
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, SummaryChrome.depthSmall)

            HStack(spacing: 12) {
                secondaryActionButton(title: "Share", symbol: "square.and.arrow.up", action: shareRun)
                secondaryActionButton(title: "Menu", symbol: "list.bullet", action: onBackToMenu)
            }
        }
    }

    private func secondaryActionButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .black))
                Text(title.uppercased())
                    .font(StitchTheme.Typography.body(size: 14, weight: .heavy))
            }
            .foregroundStyle(StitchTheme.BoardGame.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: StitchTheme.RuunChrome.buttonHeight)
            .background(
                StitchRoundedSurface(
                    fill: StitchTheme.BoardGame.surface,
                    border: StitchTheme.BoardGame.outline,
                    shadow: StitchTheme.BoardGame.outline,
                    cornerRadius: SummaryChrome.cardRadius,
                    lineWidth: StitchTheme.RuunChrome.buttonLineWidth,
                    depth: StitchTheme.RuunChrome.headerControlDepth
                )
            )
            .padding(.bottom, StitchTheme.RuunChrome.headerControlDepth)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeading(title: String, symbol: String) -> some View {
        RuunSectionHeading(title: title, symbol: symbol)
    }

    private func summaryChip(_ title: String) -> some View {
        Text(title)
            .font(StitchTheme.Typography.caption(size: 11, weight: .heavy))
            .foregroundStyle(StitchTheme.BoardGame.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(StitchTheme.BoardGame.goldWash)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(StitchTheme.BoardGame.gold.opacity(0.3), lineWidth: 1)
                    )
            )
    }

    private var bestWordLabel: String {
        guard !snapshot.bestWord.isEmpty else { return "—" }
        return snapshot.bestWord.uppercased()
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

    private func shareRun() {
        guard let image = ShareCardImageRenderer.makeImage(snapshot: snapshot) else {
            shareErrorMessage = "Could not generate share card image."
            return
        }
        let presented = ShareSheetPresenter.present(items: [image])
        if !presented {
            shareErrorMessage = "Could not present share sheet."
        }
    }
}

struct RunSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        RunSummaryView(
            snapshot: RunSummarySnapshot(
                wonRun: true,
                totalScore: 12450,
                xpEarned: 2500,
                totalXPAfterRun: 1800,
                roundsCleared: 18,
                totalRounds: 20,
                roundReached: 20,
                locksBroken: 42,
                wordsBuilt: 156,
                bestWord: "QUIXOTIC",
                bestWordScore: 840,
                challengeRoundsCleared: 5,
                rareLetterWordUsed: true,
                newUnlocks: [.startingPowerup]
            ),
            onBackToMenu: {},
            onPlayAgain: {}
        )
    }
}
