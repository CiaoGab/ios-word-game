import SwiftUI
import SpriteKit

struct GameScreen: View {
    private enum BoardVisuals {
        static let fieldOpacity: Double = 0.08
        static let dotOpacity: Double = 0.02
    }

    private enum GameChrome {
        static let screenPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 8   // 6x6 rebalance: reduced from 12 to give board more vertical space
        static let panelSpacing: CGFloat = 8     // 6x6 rebalance: reduced from 10
        static let boardHorizontalBleed: CGFloat = -6
    }

    let onQuitToMenu: () -> Void
    let starterPerks: [StarterPerkID]

    @StateObject private var session: GameSessionController
    @State private var showPause: Bool = false
    @State private var wordPillShakeTrigger: CGFloat = 0
    @State private var scorePops: [ScorePop] = []
    @State private var showBoardIntroBanner: Bool = false
    @State private var boardIntroTask: Task<Void, Never>? = nil
    @State private var submitBeat: SubmitBeat? = nil  // file-scope private type

    private struct ScorePop: Identifiable {
        let id: UUID = UUID()
        let text: String
    }



    init(
        milestoneTracker: MilestoneTracker,
        playerProfile: PlayerProfile,
        starterPerks: [StarterPerkID],
        onQuitToMenu: @escaping () -> Void
    ) {
        self.onQuitToMenu = onQuitToMenu
        self.starterPerks = starterPerks
        _session = StateObject(
            wrappedValue: GameSessionController(
                milestoneTracker: milestoneTracker,
                playerProfile: playerProfile
            )
        )
    }

    var body: some View {
        let reduceMotion = AppSettings.reduceMotion

        ZStack {
            StitchTheme.BoardGame.canvas
                .ignoresSafeArea()

            VStack(spacing: GameChrome.sectionSpacing) {
                hud

                boardSection

                VStack(spacing: GameChrome.panelSpacing) {
                    wordSelectionPill
                    submitRow
                    powerupBar
                }
            }
            .padding(.horizontal, GameChrome.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, GameChrome.screenPadding)

            // Submit score beat (Balatro-style word score presentation)
            if let beat = submitBeat {
                VStack {
                    Spacer()
                    SubmitScoreBeatView(beat: beat, reduceMotion: reduceMotion) {
                        submitBeat = nil
                    }
                    Spacer().frame(height: 225)
                }
                .zIndex(6)
                .allowsHitTesting(false)
                .padding(.horizontal, GameChrome.screenPadding + 20)
            }

            // Modifier draft overlay (shown after each board win)
            if session.showPerkDraft {
                PerkDraftView(
                    roundIndex: session.runState?.roundIndex ?? 1,
                    options: session.perkDraftOptions,
                    onSelect: { perkId in
                        session.advanceBoardAfterModifierSelection(perkId)
                    }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                .zIndex(10)
            }

            // Run summary overlay (shown on run end)
            if session.showRunSummary, let summary = session.runSummarySnapshot {
                RunSummaryView(
                    snapshot: summary,
                    onBackToMenu: {
                        session.dismissRunSummary()
                        onQuitToMenu()
                    },
                    onPlayAgain: {
                        session.restartRun(starterPerks: starterPerks)
                    }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                .zIndex(10)
            }

            if session.showRoundClearStamp {
                ZStack {
                    RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                        .fill(StitchTheme.Colors.accentGold)
                        .frame(width: 258, height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                                .stroke(StitchTheme.Colors.accentGoldStroke, lineWidth: StitchTheme.Stroke.bold)
                        )
                        .rotationEffect(.degrees(-8))
                        .shadow(color: StitchTheme.Colors.shadowColor.opacity(0.2), radius: 8, x: 0, y: 4)

                    Text("ROUND CLEARED!")
                        .font(StitchTheme.Typography.title(size: 28))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .rotationEffect(.degrees(-8))
                }
                .padding(.horizontal, 24)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.65).combined(with: .opacity))
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.12)
                        : .spring(response: 0.32, dampingFraction: 0.72),
                    value: session.showRoundClearStamp
                )
                .zIndex(12)
                .allowsHitTesting(false)
            }

            // Round-cleared popup (interactive transition between rounds)
            if let info = session.roundClearedInfo {
                RoundClearedOverlay(
                    info: info,
                    onNext: { session.confirmRoundCleared() }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                .zIndex(11)
            }

            // Powerup toast
            if let toast = session.powerupToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(StitchTheme.Typography.body(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, StitchTheme.Space._5)
                        .padding(.vertical, StitchTheme.Space._3)
                        .background(
                            RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                                .fill(StitchTheme.Colors.inkPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                                        .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
                                )
                        )
                        .shadow(color: StitchTheme.Colors.shadowColor.opacity(0.15), radius: 6, x: 0, y: 3)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .animation(.spring(duration: 0.3), value: toast)
                    Spacer().frame(height: 120)
                }
                .zIndex(20)
                .allowsHitTesting(false)
            }

            // Wildcard placing mode banner
            if session.isPlacingWildcard {
                VStack {
                    Spacer().frame(height: 60)
                    Text("Tap a tile to place Wildcard")
                        .font(StitchTheme.Typography.caption(size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, StitchTheme.Space._4)
                        .padding(.vertical, StitchTheme.Space._2)
                        .background(
                            RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
                                .fill(StitchTheme.Colors.accentGold)
                                .overlay(
                                    RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
                                        .stroke(StitchTheme.Colors.accentGoldStroke, lineWidth: StitchTheme.Stroke.hairline)
                                )
                        )
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    Spacer()
                }
                .zIndex(15)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            session.startRun(starterPerks: starterPerks)
        }
        .onDisappear {
            boardIntroTask?.cancel()
            boardIntroTask = nil
        }
        .sheet(isPresented: $showPause) {
            PauseSheet(
                runInfo: session.runState.map { PauseSheet.RunInfo(roundIndex: $0.roundIndex, act: $0.act, scoreThisBoard: $0.scoreThisBoard, scoreGoalForBoard: $0.scoreGoalForBoard) },
                playerProfile: session.playerProfile,
                onResume: { showPause = false },
                onRestartRun: {
                    showPause = false
                    session.restartRun()
                },
                onQuitRun: {
                    showPause = false
                    session.quitRunToMenu()
                    onQuitToMenu()
                }
            )
        }
        .onChange(of: showPause) { _, isShowing in
            session.setPaused(isShowing)
        }
        .onChange(of: session.showBanner) { _, shouldShow in
            guard shouldShow else { return }
            presentBoardIntroBanner()
        }
        .onChange(of: session.submitFeedbackEventID) { _, _ in
            switch session.lastSubmitOutcome {
            case .valid:
                if session.lastSubmitPoints > 0 {
                    enqueueScorePop(points: session.lastSubmitPoints)
                }
                let word = session.lastSubmittedWord
                if !word.isEmpty, session.lastSubmitPoints > 0 {
                    submitBeat = SubmitBeat(
                        word: word,
                        points: session.lastSubmitPoints,
                        bonusDetail: session.lastSubmitFeedbackDetail
                    )
                }
            case .invalid:
                withAnimation(.linear(duration: WordFeedbackStyle.Tunables.invalidShakeDuration)) {
                    wordPillShakeTrigger += 1
                }
            case .idle:
                break
            }
        }
    }

    // MARK: - HUD

    private static let hudSh = (StitchTheme.Colors.shadowColor.opacity(0.08), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))

    private var hud: some View {
        let run = session.runState
        let gearDisabled = session.showPerkDraft || session.showRunSummary || session.showRoundClearStamp || session.roundClearedInfo != nil || session.runState == nil

        return VStack(spacing: GameChrome.panelSpacing) {
            HStack(alignment: .center, spacing: GameChrome.panelSpacing) {
                if let run = run {
                    actRoundPill(act: run.act, round: run.roundIndex, total: RunState.Tunables.totalRounds)
                } else {
                    Text("—")
                        .font(StitchTheme.Typography.labelCaps(size: 12, weight: .heavy))
                        .foregroundStyle(StitchTheme.BoardGame.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                movesPill(session.moves)

                Spacer(minLength: 0)

                Button { SoundManager.shared.playButtonTap(); showPause = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            StitchRoundedSurface(
                                fill: StitchTheme.BoardGame.surfaceWarm,
                                border: StitchTheme.BoardGame.outline,
                                shadow: StitchTheme.BoardGame.outline,
                                cornerRadius: 18,
                                lineWidth: 2.4,
                                depth: StitchTheme.BoardGame.Depth.soft
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(gearDisabled)
                .opacity(gearDisabled ? 0.5 : 1)

            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(StitchTheme.BoardGame.outline)
                    .frame(height: 2)
            }

            if let run = run {
                scoreProgressPill(current: run.scoreThisBoard, target: run.scoreGoalForBoard)

                if session.isChallengeRound {
                    challengePill(
                        title: session.currentChallengeDisplayName ?? "CHALLENGE",
                        primaryRule: session.currentChallengePrimaryText ?? session.currentChallengeRuleText ?? "Special round active",
                        secondaryLabel: session.currentChallengeSecondaryLabel,
                        secondaryText: session.currentChallengeSecondaryText
                    )
                }
            }
        }
    }

    private func actRoundPill(act: Int, round: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .frame(width: 34, height: 34)
                .background(
                    StitchRoundedSurface(
                        fill: StitchTheme.BoardGame.surfaceWarm,
                        border: StitchTheme.BoardGame.outline,
                        shadow: StitchTheme.BoardGame.outline,
                        cornerRadius: 17,
                        lineWidth: 2.4,
                        depth: StitchTheme.BoardGame.Depth.soft
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                Text("BUCKET \(act)")
                    .font(StitchTheme.Typography.labelCaps(size: 12, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)

                Text("Round \(round)")
                    .font(StitchTheme.Typography.body(size: 11, weight: .bold))
                    .foregroundStyle(StitchTheme.BoardGame.gold)
            }
        }
    }

    private func movesPill(_ moves: Int) -> some View {
        VStack(spacing: 2) {
            Text("MOVES LEFT")
                .font(StitchTheme.Typography.labelCaps(size: 9, weight: .heavy))
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)

            Text("\(moves)")
                .font(StitchTheme.Typography.valueHero(size: 20).monospacedDigit())
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
        }
        .frame(width: 88, height: 48)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.gold,
                border: StitchTheme.BoardGame.outline,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: 16,
                lineWidth: 2.6,
                depth: StitchTheme.BoardGame.Depth.soft
            )
        )
    }

    private func scoreProgressPill(current: Int, target: Int) -> some View {
        let met = current >= target
        let progress = min(1.0, CGFloat(current) / CGFloat(max(target, 1)))

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("SCORE")
                    .font(StitchTheme.Typography.labelCaps(size: 9, weight: .heavy))
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)

                Spacer(minLength: 4)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(current.formatted(.number.grouping(.automatic)))
                        .font(StitchTheme.Typography.valueHero(size: 20).monospacedDigit())
                        .foregroundStyle(met ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text("/")
                        .font(StitchTheme.Typography.body(size: 13, weight: .semibold))
                        .foregroundStyle(StitchTheme.BoardGame.textMuted)

                    Text(target.formatted(.number.grouping(.automatic)))
                        .font(StitchTheme.Typography.body(size: 14, weight: .heavy).monospacedDigit())
                        .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            GeometryReader { proxy in
                let barWidth = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(StitchTheme.BoardGame.surfaceMuted)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(StitchTheme.BoardGame.outline, lineWidth: 2)
                        )
                    Capsule(style: .continuous)
                        .fill(met ? StitchTheme.BoardGame.goldStrong : StitchTheme.BoardGame.gold)
                        .frame(width: max(0, (barWidth - 4) * progress))
                        .padding(2)
                }
            }
            .frame(height: 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(panelBackground())
    }



    private func challengePill(
        title: String,
        primaryRule: String,
        secondaryLabel: String?,
        secondaryText: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(StitchTheme.Typography.labelCaps(size: 10, weight: .heavy))
                .foregroundStyle(StitchTheme.BoardGame.goldStrong)

            Text(primaryRule)
                .font(StitchTheme.Typography.body(size: 12, weight: .heavy))
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            if let secondaryLabel, let secondaryText {
                HStack(alignment: .top, spacing: 8) {
                    challengeMetaTag(text: secondaryLabel)

                    Text(secondaryText)
                        .font(StitchTheme.Typography.caption(size: 11))
                        .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surfaceWarm,
                border: StitchTheme.BoardGame.gold,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: 20,
                lineWidth: 1.8,
                depth: StitchTheme.BoardGame.Depth.soft
            )
        )
    }

    private func challengeMetaTag(text: String) -> some View {
        let isObjective = text == "OBJECTIVE"
        let fill = isObjective
            ? ParchmentTheme.Palette.objectiveTagFill
            : StitchTheme.BoardGame.gold.opacity(0.22)
        let stroke = isObjective
            ? ParchmentTheme.Palette.objectiveTagStroke
            : StitchTheme.BoardGame.gold.opacity(0.45)
        let foreground = isObjective
            ? ParchmentTheme.Palette.objectiveGreenText
            : StitchTheme.BoardGame.goldStrong

        return Text(text)
            .font(StitchTheme.Typography.labelCaps(size: 8, weight: .heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(stroke, lineWidth: 1.2)
                    )
            )
    }

    // MARK: - Board

    private var boardSection: some View {
        GeometryReader { proxy in
            let boardShape = RoundedRectangle(cornerRadius: StitchTheme.Board.cornerRadius, style: .continuous)
            let reduceMotion = AppSettings.reduceMotion

            SpriteView(
                scene: session.scene,
                options: [.allowsTransparency]
            )
                .onAppear {
                    session.updateSceneSize(proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    session.updateSceneSize(newSize)
                }
                .overlay(alignment: .top) {
                    if showBoardIntroBanner {
                        BoardIntroBanner(
                            currentAct: session.currentAct,
                            roundIndex: session.currentRound,
                            templateDisplayName: session.templateDisplayName,
                            hasStones: session.hasStones,
                            isChallengeRound: session.isChallengeRound,
                            challengePrimaryText: session.currentChallengePrimaryText ?? session.currentChallengeRuleText,
                            challengeSecondaryLabel: session.currentChallengeSecondaryLabel,
                            challengeSecondaryText: session.currentChallengeSecondaryText
                        )
                        .padding(.top, BoardIntroBanner.Tunables.topInset)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity)
                        )
                        .zIndex(25)
                        .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .top) {
                    scorePopLayer
                        .padding(.top, 8)
                }
                .background(
                    boardShape
                        .fill(StitchTheme.BoardGame.surfaceWarm.opacity(BoardVisuals.fieldOpacity))
                        .overlay {
                            StitchDotPattern(
                                color: StitchTheme.BoardGame.outline.opacity(BoardVisuals.dotOpacity),
                                spacing: 12,
                                dotSize: 2
                            )
                            .clipShape(boardShape)
                        }
                        .padding(2)
                        .allowsHitTesting(false)
                )
                .overlay {
                    boardShape
                        .stroke(StitchTheme.BoardGame.gold.opacity(0.04), lineWidth: 0.8)
                        .padding(2)
                        .allowsHitTesting(false)
                }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, GameChrome.boardHorizontalBleed)
    }

    // MARK: - Word selection pill

    private var wordSelectionPill: some View {
        let overlayLocked = session.showPerkDraft || session.showRunSummary || session.showRoundClearStamp || session.roundClearedInfo != nil || session.isPaused
        let isBuilding = !session.currentWordText.isEmpty && session.lastSubmitOutcome == .idle
        let feedbackTitle: String?
        let subtitleText: String?
        let borderColor: Color
        let textColor: Color
        let wordDisplay = session.currentWordText.isEmpty
            ? "WORD"
            : session.currentWordText.map(String.init).joined(separator: " ")

        switch session.lastSubmitOutcome {
        case .valid:
            feedbackTitle = "+\(session.lastSubmitPoints)"
            subtitleText = session.lastSubmitFeedbackDetail ?? "Great word"
            borderColor = WordFeedbackStyle.Colors.validBorder
            textColor = WordFeedbackStyle.Colors.validText
        case .invalid:
            feedbackTitle = "Not a word"
            subtitleText = nil
            borderColor = WordFeedbackStyle.Colors.invalidBorder
            textColor = WordFeedbackStyle.Colors.invalidText
        case .idle:
            feedbackTitle = nil
            subtitleText = nil
            borderColor = StitchTheme.BoardGame.gold
            textColor = isBuilding ? StitchTheme.BoardGame.textPrimary : StitchTheme.BoardGame.textSecondary
        }

        return HStack(spacing: 10) {
            VStack(spacing: subtitleText == nil ? 0 : 4) {
                if let title = feedbackTitle {
                    Text(title)
                        .font(StitchTheme.Typography.valueHero(size: 22))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                } else {
                    Text(wordDisplay)
                        .font(StitchTheme.Typography.valueHero(size: 20))
                        .tracking(session.currentWordText.isEmpty ? 3 : 5)
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                if let sub = subtitleText {
                    Text(sub)
                        .font(StitchTheme.Typography.caption(size: 11))
                        .foregroundStyle(textColor.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            if isBuilding {
                Button(action: { session.removeLastSelectionTile() }) {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 60)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surface,
                border: borderColor,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: 22,
                lineWidth: 2.2,
                depth: StitchTheme.BoardGame.Depth.soft,
                dash: session.lastSubmitOutcome == .idle ? [6, 4] : []
            )
        )
        .padding(.bottom, StitchTheme.BoardGame.Depth.soft)
        .modifier(ShakeEffect(animatableData: wordPillShakeTrigger, amplitude: WordFeedbackStyle.Tunables.invalidShakeAmplitude, shakesPerUnit: WordFeedbackStyle.Tunables.invalidShakesPerUnit))
        .onTapGesture {
            if !overlayLocked {
                session.clearCurrentSelection()
            }
        }
        .allowsHitTesting(!overlayLocked)
    }

    // MARK: - Powerup bar (Hint / Shuffle / Wildcard / Undo)

    private var powerupBar: some View {
        let locked = session.isPaused
            || session.isAnimating
            || session.showPerkDraft
            || session.showRunSummary
            || session.showRoundClearStamp
            || session.roundClearedInfo != nil
        let inv = session.runState?.inventory ?? Inventory()
        let shuffles = session.runState?.shufflesRemaining ?? session.shufflesRemaining

        return HStack(spacing: 10) {
            powerupButton(type: .hint, count: inv.hints, locked: locked) { session.useHint() }
            powerupButton(type: .shuffle, count: shuffles, locked: locked) { session.useShuffle() }
            powerupButton(type: .wildcard, count: inv.wildcards, locked: locked, isHighlighted: session.isPlacingWildcard) { session.startWildcardPlacement() }
            powerupButton(type: .undo, count: inv.undos, locked: locked || !session.canUndo) { session.useUndo() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surfaceWarm,
                border: StitchTheme.BoardGame.outline,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: 16,
                lineWidth: 2.2,
                depth: StitchTheme.BoardGame.Depth.soft
            )
        )
        .padding(.bottom, StitchTheme.BoardGame.Depth.soft)
    }

    private func powerupButton(
        type: PowerupType,
        count: Int,
        locked: Bool,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isDisabled = count == 0 || locked

        return Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: type.systemIcon)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(isDisabled ? StitchTheme.BoardGame.textMuted : StitchTheme.BoardGame.textPrimary)
                        .frame(width: 46, height: 46)
                        .background(
                            StitchRoundedSurface(
                                fill: StitchTheme.BoardGame.surface,
                                border: isHighlighted && !isDisabled ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.outline,
                                shadow: StitchTheme.BoardGame.outline,
                                cornerRadius: 15,
                                lineWidth: isHighlighted && !isDisabled ? 2.4 : 2.0,
                                depth: StitchTheme.BoardGame.Depth.soft
                            )
                        )

                    Text("\(count)")
                        .font(StitchTheme.Typography.labelCaps(size: 9, weight: .heavy).monospacedDigit())
                        .foregroundStyle(isDisabled ? StitchTheme.BoardGame.textMuted : StitchTheme.BoardGame.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(StitchTheme.BoardGame.surface)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(StitchTheme.BoardGame.outline, lineWidth: 1.6)
                                )
                        )
                        .offset(x: 4, y: -5)
                }

                Text(type.displayName.uppercased())
                    .font(StitchTheme.Typography.labelCaps(size: 9, weight: .heavy))
                    .foregroundStyle(isDisabled ? StitchTheme.BoardGame.textMuted : StitchTheme.BoardGame.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
    }

    // MARK: - Submit row

    private var submitRow: some View {
        let selectionCount = session.currentSelectionIndices.count
        let submitCost = session.computeSubmitCost(selectionIndices: session.currentSelectionIndices)
        let hasValidLength = (session.minimumSubmitLength...session.maximumSubmitLength).contains(selectionCount)
        let canSubmit = hasValidLength
            && session.moves >= submitCost
            && !session.isPaused
            && !session.isAnimating
            && !session.showPerkDraft
            && !session.showRunSummary
            && !session.showRoundClearStamp
            && session.roundClearedInfo == nil
        let costLabel = session.submitCostLabel(selectionIndices: session.currentSelectionIndices)

        return VStack(spacing: 4) {
            Button(action: {
                session.submitPath(indices: session.currentSelectionIndices)
            }) {
                Text("Submit")
                    .font(StitchTheme.Typography.valueHero(size: 18))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        StitchRoundedSurface(
                            fill: canSubmit ? StitchTheme.BoardGame.gold : StitchTheme.BoardGame.surfaceMuted,
                            border: StitchTheme.BoardGame.outline,
                            shadow: StitchTheme.BoardGame.outline,
                            cornerRadius: 22,
                            lineWidth: 2.6,
                            depth: StitchTheme.BoardGame.Depth.soft
                        )
                    )
                    .padding(.bottom, StitchTheme.BoardGame.Depth.soft)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in session.clearCurrentSelection() }
            )

            Text(costLabel)
                .font(StitchTheme.Typography.caption(size: 10))
                .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                .opacity(selectionCount > 0 ? 1 : 0)

        }
    }


    // MARK: - Score pop

    @ViewBuilder
    private var scorePopLayer: some View {
        ZStack {
            ForEach(Array(scorePops.enumerated()), id: \.element.id) { offset, pop in
                FloatingScorePop(
                    text: pop.text,
                    rise: WordFeedbackStyle.Tunables.scorePopRise,
                    duration: WordFeedbackStyle.Tunables.scorePopDuration
                ) {
                    scorePops.removeAll { $0.id == pop.id }
                }
                .offset(y: CGFloat(offset * 12))
            }
        }
        .allowsHitTesting(false)
    }

    private func enqueueScorePop(points: Int) {
        guard points > 0 else { return }
        scorePops.append(ScorePop(text: "+\(points)"))
    }

    private func presentBoardIntroBanner() {
        let reduceMotion = AppSettings.reduceMotion
        boardIntroTask?.cancel()

        withAnimation(
            reduceMotion
                ? .easeOut(duration: BoardIntroBanner.Tunables.reducedInDuration)
                : .spring(response: BoardIntroBanner.Tunables.inAnimationDuration, dampingFraction: 0.82)
        ) {
            showBoardIntroBanner = true
        }

        boardIntroTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(
                    (reduceMotion
                     ? BoardIntroBanner.Tunables.reducedDisplayDuration
                     : BoardIntroBanner.Tunables.displayDuration) * 1_000_000_000
                )
            )
            guard !Task.isCancelled else { return }
            withAnimation(
                reduceMotion
                    ? .easeIn(duration: BoardIntroBanner.Tunables.reducedOutDuration)
                    : .easeInOut(duration: BoardIntroBanner.Tunables.outAnimationDuration)
            ) {
                showBoardIntroBanner = false
            }
        }
    }

    // MARK: - Shared view helpers

    private func panelBackground(
        fill: Color = StitchTheme.BoardGame.surface,
        border: Color = StitchTheme.BoardGame.outline
    ) -> some View {
        StitchRoundedSurface(
            fill: fill,
            border: border,
            shadow: StitchTheme.BoardGame.outline,
            cornerRadius: 20,
            lineWidth: 2.4,
            depth: StitchTheme.BoardGame.Depth.soft
        )
    }
}



// MARK: - Pause sheet

private struct PauseSheet: View {
    struct RunInfo {
        let roundIndex: Int
        let act: Int
        let scoreThisBoard: Int
        let scoreGoalForBoard: Int
    }

    let runInfo: RunInfo?
    let playerProfile: PlayerProfile?
    let onResume: () -> Void
    let onRestartRun: () -> Void
    let onQuitRun: () -> Void

    @State private var showSettings: Bool = false
    @State private var showRestartConfirmation: Bool = false
    @State private var showQuitConfirmation: Bool = false

    private let sh = StitchTheme.Shadow.sheet
    private let panelRadius: CGFloat = 32

    var body: some View {
        ZStack {
            StitchTheme.Colors.backdrop
                .ignoresSafeArea()
                .onTapGesture { }

            pausePanel
                .padding(.horizontal, StitchTheme.Space._5)
                .padding(.vertical, StitchTheme.Space._6)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
        .sheet(isPresented: $showSettings) {
            SettingsView(playerProfile: playerProfile)
        }
        .overlay {
            if showRestartConfirmation {
                confirmationCard(
                    title: "Restart Run?",
                    message: "You'll lose current progress for this run.",
                    cancel: { showRestartConfirmation = false },
                    confirmTitle: "Restart",
                    onConfirm: onRestartRun
                )
            }
            if showQuitConfirmation {
                confirmationCard(
                    title: "Quit Run?",
                    message: "You'll return to the menu. Run progress will be lost.",
                    cancel: { showQuitConfirmation = false },
                    confirmTitle: "Quit Run",
                    onConfirm: onQuitRun
                )
            }
        }
    }

    private var pausePanel: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
                .overlay(StitchTheme.Colors.strokeStandard)
                .padding(.vertical, StitchTheme.Space._4)

            VStack(spacing: StitchTheme.Space._3) {
                Button(action: onResume) { Text("Resume") }
                    .buttonStyle(StitchPrimaryButtonStyle())

                Button(action: { showSettings = true }) { Text("Settings") }
                    .buttonStyle(StitchSecondaryButtonStyle())

                pauseDangerButton("Restart Run") { showRestartConfirmation = true }
                pauseDangerButton("Quit Run") { showQuitConfirmation = true }
            }
        }
        .padding(StitchTheme.Space._6)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
                .fill(StitchTheme.Colors.bgSheet)
                .overlay(
                    RoundedRectangle(cornerRadius: panelRadius, style: .continuous)
                        .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
                )
        )
        .shadow(color: sh.color, radius: sh.radius, x: sh.x, y: sh.y)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Space._2) {
            Text("PAUSED")
                .font(StitchTheme.Typography.labelCaps(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundStyle(StitchTheme.Colors.inkSecondary)

            if let info = runInfo {
                Text("Bucket \(info.act) · Round \(info.roundIndex)/\(RunState.Tunables.totalRounds)")
                    .font(StitchTheme.Typography.caption(size: 13))
                    .foregroundStyle(StitchTheme.Colors.inkMuted)
                Text("Score \(info.scoreThisBoard) / \(info.scoreGoalForBoard)")
                    .font(StitchTheme.Typography.body(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(StitchTheme.Colors.inkPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pauseDangerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title) }
            .buttonStyle(StitchDestructiveButtonStyle())
    }

    private func confirmationCard(
        title: String,
        message: String,
        cancel: @escaping () -> Void,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        ZStack {
            StitchTheme.Colors.backdrop
                .ignoresSafeArea()
                .onTapGesture(perform: cancel)

            VStack(spacing: StitchTheme.Space._5) {
                Text(title)
                    .font(StitchTheme.Typography.body(size: 18, weight: .heavy))
                    .foregroundStyle(StitchTheme.Colors.inkPrimary)
                Text(message)
                    .font(StitchTheme.Typography.caption(size: 14))
                    .foregroundStyle(StitchTheme.Colors.inkSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: StitchTheme.Space._3) {
                    Button(action: cancel) { Text("Cancel") }
                        .buttonStyle(StitchSecondaryButtonStyle())
                    Button(action: onConfirm) { Text(confirmTitle) }
                        .buttonStyle(StitchDestructiveButtonStyle())
                }
            }
            .padding(StitchTheme.Space._6)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: StitchTheme.Radii.xl, style: .continuous)
                    .fill(StitchTheme.Colors.bgSheet)
                    .overlay(
                        RoundedRectangle(cornerRadius: StitchTheme.Radii.xl, style: .continuous)
                            .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
            .shadow(color: sh.color, radius: sh.radius, x: sh.x, y: sh.y)
        }
        .transition(AppSettings.reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
    }

}

// MARK: - Parchment backdrop (shared with StartScreen and MilestonesScreen)

struct ParchmentBackdrop: View {
    var body: some View {
        ZStack {
            ParchmentTheme.Palette.paperBase

            Canvas { context, size in
                for row in 0...12 {
                    for col in 0...7 {
                        let x = (CGFloat(col) + 0.4) * (size.width / 7.5)
                        let y = (CGFloat(row) + 0.35) * (size.height / 12.5)
                        let dot = CGRect(x: x, y: y, width: 2.2, height: 2.2)
                        context.fill(Ellipse().path(in: dot), with: .color(ParchmentTheme.Palette.paperDust.opacity(0.24)))

                        let smudge = CGRect(x: x - 26, y: y - 9, width: 52, height: 18)
                        context.fill(
                            Ellipse().path(in: smudge),
                            with: .color(ParchmentTheme.Palette.paperDust.opacity(0.09))
                        )
                    }
                }

                var doodle = Path()
                doodle.move(to: CGPoint(x: 24, y: 36))
                doodle.addCurve(
                    to: CGPoint(x: 176, y: 132),
                    control1: CGPoint(x: 92, y: 8),
                    control2: CGPoint(x: 136, y: 178)
                )
                context.stroke(
                    doodle,
                    with: .color(ParchmentTheme.Palette.paperDoodle.opacity(0.3)),
                    lineWidth: 2.5
                )

                var doodle2 = Path()
                doodle2.addEllipse(in: CGRect(x: size.width - 84, y: 22, width: 30, height: 30))
                context.stroke(
                    doodle2,
                    with: .color(ParchmentTheme.Palette.paperDoodle.opacity(0.22)),
                    lineWidth: 2.5
                )
            }
        }
    }
}

// MARK: - Submit Score Beat (Balatro-style word score presentation)

private struct SubmitBeat: Identifiable {
    let id: UUID = UUID()
    let word: String
    let points: Int
    let bonusDetail: String?
}

private struct SubmitScoreBeatView: View {
    let beat: SubmitBeat
    let reduceMotion: Bool
    let onDismiss: () -> Void

    private enum Timing {
        static let enterDuration: TimeInterval = 0.14
        static let countSteps: Int = 18
        static let countDuration: TimeInterval = 0.30
        static let holdDuration: TimeInterval = 0.14
        static let exitDuration: TimeInterval = 0.16
    }

    @State private var visible: Bool = false
    @State private var displayedPoints: Int = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var beatTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 5) {
            // Submitted word
            Text(beat.word.map(String.init).joined(separator: " "))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(3.5)
                .foregroundStyle(StitchTheme.BoardGame.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Score delta
            Text("+\(displayedPoints)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(StitchTheme.BoardGame.gold)
                .monospacedDigit()
                .scaleEffect(pulseScale)

            // Optional perk bonus
            if let detail = beat.bonusDetail {
                Text(detail)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(StitchTheme.BoardGame.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            StitchRoundedSurface(
                fill: StitchTheme.BoardGame.surface,
                border: StitchTheme.BoardGame.gold,
                shadow: StitchTheme.BoardGame.outline,
                cornerRadius: 20,
                lineWidth: 2.4,
                depth: 4
            )
        )
        .shadow(color: StitchTheme.BoardGame.outline.opacity(0.18), radius: 14, x: 0, y: 6)
        .scaleEffect(visible ? 1.0 : (reduceMotion ? 1.0 : 0.80))
        .opacity(visible ? 1.0 : 0.0)
        .onAppear { startBeatSequence() }
        .onDisappear { beatTask?.cancel() }
    }

    private func startBeatSequence() {
        beatTask?.cancel()
        beatTask = Task { @MainActor in
            // Enter
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: Timing.enterDuration, dampingFraction: 0.72)
            ) {
                visible = true
            }
            try? await Task.sleep(nanoseconds: UInt64(Timing.enterDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            // Count up
            let steps = Timing.countSteps
            let stepDelay = Timing.countDuration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                let progress = Double(i) / Double(steps)
                let eased = 1.0 - pow(1.0 - progress, 2.2)
                displayedPoints = Int((Double(beat.points) * eased).rounded())
                // Play a soft tick every 3 count steps (keeps it subtle, not spammy).
                if i % 3 == 0 || i == steps {
                    SoundManager.shared.playTallyTick()
                }
            }
            displayedPoints = beat.points

            // Micro-pulse on landing
            if !reduceMotion {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                    pulseScale = 1.12
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.14, dampingFraction: 0.72)) {
                    pulseScale = 1.0
                }
            }

            // Hold
            try? await Task.sleep(nanoseconds: UInt64(Timing.holdDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            // Exit
            withAnimation(.easeIn(duration: Timing.exitDuration)) {
                visible = false
            }
            try? await Task.sleep(nanoseconds: UInt64(Timing.exitDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}

private struct FloatingScorePop: View {
    let text: String
    let rise: CGFloat
    let duration: TimeInterval
    let onFinish: () -> Void

    @State private var animateOut = false

    var body: some View {
        Text(text)
            .font(StitchTheme.Typography.valueHero(size: 24))
            .foregroundStyle(StitchTheme.Colors.accentGold)
            .padding(.horizontal, StitchTheme.Space._3)
            .padding(.vertical, StitchTheme.Space._1)
            .background(
                RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
                    .fill(StitchTheme.Colors.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: StitchTheme.Radii.sm, style: .continuous)
                            .stroke(StitchTheme.Colors.accentGold, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
            .shadow(color: StitchTheme.Colors.shadowColor.opacity(0.12), radius: 4, x: 0, y: 2)
            .offset(y: animateOut ? -rise : 0)
            .opacity(animateOut ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    animateOut = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    onFinish()
                }
            }
    }
}

private struct BoardIntroBanner: View {
    enum Tunables {
        static let displayDuration: TimeInterval = 0.9
        static let reducedDisplayDuration: TimeInterval = 0.6
        static let inAnimationDuration: TimeInterval = 0.28
        static let outAnimationDuration: TimeInterval = 0.2
        static let reducedInDuration: TimeInterval = 0.12
        static let reducedOutDuration: TimeInterval = 0.1
        static let topInset: CGFloat = 12
    }

    let currentAct: Int
    let roundIndex: Int
    let templateDisplayName: String
    let hasStones: Bool
    let isChallengeRound: Bool
    let challengePrimaryText: String?
    let challengeSecondaryLabel: String?
    let challengeSecondaryText: String?

    private var badges: [String] {
        var items: [String] = ["FREE PICK"]
        if hasStones { items.append("STONES") }
        if isChallengeRound { items.append("CHALLENGE") }
        return items
    }

    var body: some View {
        VStack(spacing: StitchTheme.Space._2) {
            Text("BUCKET \(currentAct) · ROUND \(roundIndex)")
                .font(StitchTheme.Typography.labelCaps(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(StitchTheme.Colors.inkSecondary)

            Text(templateDisplayName)
                .font(StitchTheme.Typography.title(size: 22))
                .foregroundStyle(StitchTheme.Colors.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if let challengePrimaryText, isChallengeRound {
                Text(challengePrimaryText)
                    .font(StitchTheme.Typography.caption(size: 11))
                    .foregroundStyle(StitchTheme.Colors.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)
            }

            if
                let challengeSecondaryLabel,
                let challengeSecondaryText,
                isChallengeRound
            {
                HStack(spacing: StitchTheme.Space._2) {
                    Text(challengeSecondaryLabel)
                        .font(StitchTheme.Typography.labelCaps(size: 9, weight: .heavy))
                        .tracking(0.7)
                        .foregroundStyle(challengeSecondaryLabel == "OBJECTIVE"
                            ? ParchmentTheme.Palette.objectiveGreenText
                            : StitchTheme.Colors.accentGold)
                        .padding(.horizontal, StitchTheme.Space._2)
                        .padding(.vertical, StitchTheme.Space._1)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    challengeSecondaryLabel == "OBJECTIVE"
                                        ? ParchmentTheme.Palette.objectiveTagFill
                                        : StitchTheme.Colors.accentGold.opacity(0.12)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(
                                            challengeSecondaryLabel == "OBJECTIVE"
                                                ? ParchmentTheme.Palette.objectiveTagStroke
                                                : StitchTheme.Colors.accentGold.opacity(0.28),
                                            lineWidth: StitchTheme.Stroke.hairline
                                        )
                                )
                        )

                    Text(challengeSecondaryText)
                        .font(StitchTheme.Typography.caption(size: 11))
                        .foregroundStyle(StitchTheme.Colors.inkSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.82)
                }
            }

            if !badges.isEmpty {
                HStack(spacing: StitchTheme.Space._2) {
                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(StitchTheme.Typography.labelCaps(size: 10))
                            .tracking(0.7)
                            .foregroundStyle(StitchTheme.Colors.inkPrimary)
                            .padding(.horizontal, StitchTheme.Space._2)
                            .padding(.vertical, StitchTheme.Space._1)
                            .background(
                                RoundedRectangle(cornerRadius: StitchTheme.Radii.xs, style: .continuous)
                                    .fill(StitchTheme.Colors.surfaceCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: StitchTheme.Radii.xs, style: .continuous)
                                            .stroke(StitchTheme.Colors.strokeSoft, lineWidth: StitchTheme.Stroke.hairline)
                                    )
                            )
                    }
                }
            }
        }
        .padding(.horizontal, StitchTheme.Space._4)
        .padding(.vertical, StitchTheme.Space._3)
        .background(
            RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                .fill(StitchTheme.Colors.surfaceCard)
                .overlay(
                    RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                        .stroke(StitchTheme.Colors.strokeSoft, lineWidth: StitchTheme.Stroke.standard)
                )
        )
        .shadow(color: StitchTheme.Colors.shadowColor.opacity(0.10), radius: 8, x: 0, y: 4)
        .padding(.horizontal, StitchTheme.Space._5)
    }
}

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    let amplitude: CGFloat
    let shakesPerUnit: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translationX = amplitude * sin(animatableData * .pi * shakesPerUnit * 2)
        return ProjectionTransform(CGAffineTransform(translationX: translationX, y: 0))
    }
}

struct GameScreen_Previews: PreviewProvider {
    static var previews: some View {
        GameScreen(
            milestoneTracker: MilestoneTracker(),
            playerProfile: PlayerProfile(),
            starterPerks: [],
            onQuitToMenu: {}
        )
    }
}
