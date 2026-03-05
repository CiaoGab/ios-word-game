import SwiftUI
import SpriteKit

struct GameScreen: View {
    private enum BoardVisuals {
        static let textureOpacity: Double = 0.15
    }

    let onQuitToMenu: () -> Void

    @StateObject private var session: GameSessionController
    @State private var showDebugHUD: Bool = false
    @State private var showPause: Bool = false
    @State private var wordPillShakeTrigger: CGFloat = 0
    @State private var scorePops: [ScorePop] = []
    @State private var showBoardIntroBanner: Bool = false
    @State private var boardIntroTask: Task<Void, Never>? = nil

    private struct ScorePop: Identifiable {
        let id: UUID = UUID()
        let text: String
    }

    init(milestoneTracker: MilestoneTracker, onQuitToMenu: @escaping () -> Void) {
        self.onQuitToMenu = onQuitToMenu
        _session = StateObject(wrappedValue: GameSessionController(milestoneTracker: milestoneTracker))
    }

    var body: some View {
        let reduceMotion = AppSettings.reduceMotion

        ZStack {
            ParchmentBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                hud

                boardSection
                    .padding(.top, 8)           // HUD → board: slightly tighter

                // board→pill: 14   pill→submit: 11   submit→powerups: 13
                VStack(spacing: 0) {
                    wordSelectionPill
                        .padding(.bottom, 11)
                    submitRow
                        .padding(.bottom, 13)
                    powerupBar
                    #if DEBUG
                    debugOverlay
                    #endif
                }
                .padding(.top, 14)              // board → word pill
            }
            .padding(.horizontal, ParchmentTheme.Spacing.lg)
            .padding(.top, ParchmentTheme.Spacing.lg)
            .padding(.bottom, 10)               // powerups → safe area

            // Modifier draft overlay (shown after each board win)
            if session.showPerkDraft {
                PerkDraftView(
                    boardIndex: session.runState?.boardIndex ?? 1,
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
                        session.restartRun()
                    }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                .zIndex(10)
            }

            if session.showRoundClearStamp {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ParchmentTheme.Palette.footerRed.opacity(0.92))
                        .frame(width: 258, height: 110)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(ParchmentTheme.Palette.footerRedStroke, lineWidth: 6)
                        )
                        .rotationEffect(.degrees(-8))
                        .shadow(color: ParchmentTheme.Palette.ink.opacity(0.22), radius: 8, x: 0, y: 4)

                    Text("BOARD CLEARED!")
                        .font(.parchmentRounded(size: 30, weight: .heavy))
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

            // Powerup toast
            if let toast = session.powerupToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.parchmentRounded(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ParchmentTheme.Palette.footerPurple)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(ParchmentTheme.Palette.footerPurpleStroke, lineWidth: 2)
                                )
                        )
                        .shadow(color: ParchmentTheme.Palette.ink.opacity(0.18), radius: 6, x: 0, y: 3)
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
                        .font(.parchmentRounded(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ParchmentTheme.Palette.footerPurple.opacity(0.92))
                        )
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    Spacer()
                }
                .zIndex(15)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            session.startRun()
        }
        .onDisappear {
            boardIntroTask?.cancel()
            boardIntroTask = nil
        }
        .sheet(isPresented: $showPause) {
            PauseSheet(
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

    private var hud: some View {
        let run = session.runState

        return VStack(spacing: ParchmentTheme.Spacing.sm) {
            // Row 1: Board + Moves + Gear
            HStack {
                if let run = run {
                    hudPill(title: "Board", value: "\(run.boardIndex)/\(RunState.Tunables.totalBoards)")
                } else {
                    hudPill(title: "Board", value: "—")
                }
                Spacer()
                hudPill(title: "Moves", value: "\(session.moves)")
                hudPill(
                    title: "Mods",
                    value: "\(run?.activePerks.count ?? 0)"
                )

                // Gear / pause button
                Button {
                    showPause = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ParchmentTheme.Palette.slate)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(
                    session.showPerkDraft
                    || session.showRunSummary
                    || session.showRoundClearStamp
                    || session.runState == nil
                )

                #if DEBUG
                Button { showDebugHUD.toggle() } label: {
                    Image(systemName: showDebugHUD ? "ladybug.fill" : "ladybug")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            showDebugHUD
                                ? ParchmentTheme.Palette.footerPurple
                                : ParchmentTheme.Palette.slate.opacity(0.4)
                        )
                        .frame(width: 28, height: 44)
                }
                .buttonStyle(.plain)
                #endif
            }

            // Row 2: Dual objectives (Locks + Score)
            if let run = run {
                let locksMet = run.locksBrokenThisBoard >= run.locksGoalForBoard
                let scoreMet = run.scoreThisBoard >= run.scoreGoalForBoard

                HStack(spacing: ParchmentTheme.Spacing.sm) {
                    objectivePill(
                        label: "Locks",
                        current: run.locksBrokenThisBoard,
                        target: run.locksGoalForBoard,
                        met: locksMet
                    )
                    objectivePill(
                        label: "Score",
                        current: run.scoreThisBoard,
                        target: run.scoreGoalForBoard,
                        met: scoreMet
                    )
                }
            }
        }
    }

    private func objectivePill(label: String, current: Int, target: Int, met: Bool) -> some View {
        let fill: Color = met ? ParchmentTheme.Palette.objectiveGreen.opacity(0.18) : ParchmentTheme.Palette.white
        let strokeColor: Color = met ? ParchmentTheme.Palette.objectiveGreen : ParchmentTheme.Palette.ink.opacity(0.55)
        let textColor: Color = met ? ParchmentTheme.Palette.objectiveGreenText : ParchmentTheme.Palette.ink

        return VStack(spacing: 1) {
            Text(label.uppercased())
                .font(.parchmentRounded(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(met ? ParchmentTheme.Palette.objectiveGreenText : ParchmentTheme.Palette.slate)
            Text("\(current)/\(target)")
                .font(.parchmentRounded(size: 17, weight: .heavy).monospacedDigit())
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(fill)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(strokeColor, lineWidth: ParchmentTheme.Stroke.hud)
                )
        )
        .shadow(
            color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.hud.opacity),
            radius: ParchmentTheme.Shadow.hud.radius,
            x: ParchmentTheme.Shadow.hud.x,
            y: ParchmentTheme.Shadow.hud.y
        )
    }

    // MARK: - Board

    private var boardSection: some View {
        GeometryReader { proxy in
            let boardShape = RoundedRectangle(cornerRadius: ParchmentTheme.Radius.boardOuter, style: .continuous)
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
                            boardIndex: session.boardIndex,
                            templateDisplayName: session.templateDisplayName,
                            hasStones: session.hasStones,
                            isBoss: session.isBoss
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
                        .fill(ParchmentTheme.Palette.boardOuter)
                        .overlay {
                            Image("board_texture")
                                .resizable()
                                .scaledToFill()
                                .opacity(BoardVisuals.textureOpacity)
                                .clipShape(boardShape)
                        }
                        .overlay(
                            boardShape
                                .stroke(ParchmentTheme.Palette.boardInset, lineWidth: 1.6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ParchmentTheme.Radius.boardInner, style: .continuous)
                                .stroke(
                                    ParchmentTheme.Palette.boardDash,
                                    style: StrokeStyle(lineWidth: 1.2, dash: [7, 5], dashPhase: 0)
                                )
                                .padding(6)
                        )
                )
                .clipShape(boardShape)
        }
        .shadow(
            color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.board.opacity),
            radius: ParchmentTheme.Shadow.board.radius,
            x: ParchmentTheme.Shadow.board.x,
            y: ParchmentTheme.Shadow.board.y
        )
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Word selection pill

    private var wordSelectionPill: some View {
        let overlayLocked = session.showPerkDraft || session.showRunSummary || session.showRoundClearStamp || session.isPaused
        let isBuilding = !session.currentWordText.isEmpty && session.lastSubmitOutcome == .idle

        // feedbackTitle is non-nil only during valid/invalid flash; nil → show mini tiles
        let feedbackTitle: String?
        let subtitleText: String?
        let borderColor: Color
        let textColor: Color

        switch session.lastSubmitOutcome {
        case .valid:
            feedbackTitle = "+\(session.lastSubmitPoints)"
            subtitleText = "Great word"
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
            borderColor = isBuilding ? ParchmentTheme.Palette.ink : ParchmentTheme.Palette.slate.opacity(0.35)
            textColor = ParchmentTheme.Palette.slate
        }

        return HStack(spacing: 10) {
            VStack(spacing: subtitleText == nil ? 0 : 2) {
                if let title = feedbackTitle {
                    // Valid / invalid flash: plain text feedback
                    Text(title)
                        .font(.parchmentRounded(size: 18, weight: .heavy))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                } else {
                    // Idle: mini tile row (or placeholder when empty)
                    WordPillTiles(
                        letters: session.currentSelectionLetters,
                        tileMeta: session.currentSelectionMeta
                    )
                }
                if let sub = subtitleText {
                    Text(sub)
                        .font(.parchmentRounded(size: 11, weight: .bold))
                        .foregroundStyle(textColor.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            if isBuilding {
                Button(action: { session.removeLastSelectionTile() }) {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ParchmentTheme.Palette.slate)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)             // 34pt tile + 10+10 = 54pt pill height
        .background(
            Capsule(style: .continuous)
                .fill(ParchmentTheme.Palette.white.opacity(session.lastSubmitOutcome == .idle && !isBuilding ? 0.86 : 1))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(borderColor, lineWidth: ParchmentTheme.Stroke.hud)
                )
        )
        .shadow(
            color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.hud.opacity * 0.7),
            radius: ParchmentTheme.Shadow.hud.radius,
            x: ParchmentTheme.Shadow.hud.x,
            y: ParchmentTheme.Shadow.hud.y
        )
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
        let inv = session.runState?.inventory ?? Inventory()
        let shuffles = session.runState?.shufflesRemaining ?? session.shufflesRemaining

        return HStack(spacing: ParchmentTheme.Spacing.sm) {
            powerupButton(
                type: .hint,
                count: inv.hints,
                fill: ParchmentTheme.Palette.footerBlue,
                stroke: ParchmentTheme.Palette.footerBlueStroke,
                locked: locked
            ) {
                session.useHint()
            }

            powerupButton(
                type: .shuffle,
                count: shuffles,
                fill: ParchmentTheme.Palette.footerYellow,
                stroke: ParchmentTheme.Palette.footerYellowStroke,
                locked: locked
            ) {
                session.useShuffle()
            }

            powerupButton(
                type: .wildcard,
                count: inv.wildcards,
                fill: ParchmentTheme.Palette.footerPurple,
                stroke: ParchmentTheme.Palette.footerPurpleStroke,
                locked: locked,
                isHighlighted: session.isPlacingWildcard
            ) {
                session.startWildcardPlacement()
            }

            powerupButton(
                type: .undo,
                count: inv.undos,
                fill: Color(hex: 0xFF922B),
                stroke: Color(hex: 0xD9480F),
                locked: locked || !session.canUndo
            ) {
                session.useUndo()
            }
        }
    }

    private func powerupButton(
        type: PowerupType,
        count: Int,
        fill: Color,
        stroke: Color,
        locked: Bool,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let isEmpty = count == 0
        let isDisabled = isEmpty || locked

        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Image(systemName: type.systemIcon)
                        .font(.system(size: 14, weight: .bold))
                    Text(type.displayName)
                        .font(.parchmentRounded(size: 9, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white.opacity(isDisabled ? 0.45 : 1.0))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                        .fill(fill.opacity(isDisabled ? 0.40 : (isHighlighted ? 0.95 : 1.0)))
                        .overlay(
                            RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                                .stroke(
                                    stroke.opacity(isDisabled ? 0.30 : 1.0),
                                    lineWidth: isHighlighted ? ParchmentTheme.Stroke.button + 1.5 : ParchmentTheme.Stroke.button
                                )
                        )
                )
                .shadow(
                    color: ParchmentTheme.Palette.ink.opacity(isDisabled ? 0.05 : ParchmentTheme.Shadow.button.opacity * 0.6),
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
                .overlay(
                    RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                        .stroke(Color.white.opacity(isHighlighted && !isDisabled ? 0.7 : 0.0), lineWidth: 2)
                        .padding(1)
                )

                // Count badge
                Text("\(count)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isDisabled ? Color.gray.opacity(0.50) : stroke)
                    )
                    .offset(x: -4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - Submit row

    private var submitRow: some View {
        let selectionCount = session.currentSelectionIndices.count
        let submitCost = session.computeSubmitCost(selectionIndices: session.currentSelectionIndices)
        let hasValidLength = (4...8).contains(selectionCount)
        let canSubmit = hasValidLength
            && session.moves >= submitCost
            && !session.isPaused
            && !session.isAnimating
            && !session.showPerkDraft
            && !session.showRunSummary
            && !session.showRoundClearStamp
        let costLabel = submitCost == 2 ? "Cost: 2 (LOCKED)" : "Cost: 1"

        return VStack(spacing: 4) {
            Button(action: {
                session.submitPath(indices: session.currentSelectionIndices)
            }) {
                toyLabel(
                    "Submit",
                    fill: ParchmentTheme.Palette.footerRed.opacity(canSubmit ? 1.0 : 0.45),
                    stroke: ParchmentTheme.Palette.footerRedStroke.opacity(canSubmit ? 1.0 : 0.35)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .shadow(
                color: ParchmentTheme.Palette.footerRed.opacity(canSubmit ? 0.22 : 0),
                radius: 10, x: 0, y: 2
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in session.clearCurrentSelection() }
            )

            Text(costLabel)
                .font(.parchmentRounded(size: 11, weight: .bold))
                .foregroundStyle(ParchmentTheme.Palette.slate.opacity(0.8))
                .opacity(selectionCount > 0 ? 1 : 0)

            Text("Select 4–8 letters")
                .font(.parchmentRounded(size: 11, weight: .bold))
                .foregroundStyle(ParchmentTheme.Palette.slate.opacity(0.65))
                .opacity(canSubmit ? 0 : 1)
        }
    }

    // MARK: - Debug overlay

    @ViewBuilder
    private var debugOverlay: some View {
        if showDebugHUD {
            VStack(spacing: 4) {
                HStack {
                    Text("lastSubmittedWord: \(session.lastSubmittedWord.isEmpty ? "—" : session.lastSubmittedWord)")
                    Spacer()
                }

                HStack {
                    Text("status: \(session.status)")
                    Spacer()
                }

                HStack {
                    Text("locksBrokenThisMove: \(session.locksBrokenThisMove)")
                    Spacer()
                }

                HStack {
                    Text("locksBrokenTotal: \(session.locksBrokenTotal)")
                    Spacer()
                }

                HStack {
                    Text("currentLockedCount: \(session.currentLockedCount)")
                    Spacer()
                }

                HStack {
                    Text("usedTileIdsCount: \(session.usedTileIdsCount)")
                    Spacer()
                }

                HStack {
                    Text("activePathLength: \(session.activePathLength)")
                    Spacer()
                }

                HStack {
                    Text("hintWord: \(session.hintWord ?? "—")")
                    Spacer()
                }

                HStack {
                    Text("hintIndices: \(session.hintPath?.map { "\($0)" }.joined(separator: ",") ?? "—")")
                    Spacer()
                }

                HStack {
                    Text("hintIsValid: \(session.hintIsValid ? "true" : "false")")
                    Spacer()
                }

                if let run = session.runState {
                    Divider()
                    HStack {
                        Text("board: \(run.boardIndex)/\(RunState.Tunables.totalBoards) boss:\(run.isBossBoard ? "Y" : "N")")
                        Spacer()
                    }
                    HStack {
                        Text("locks: \(run.locksBrokenThisBoard)/\(run.locksGoalForBoard)  score: \(run.scoreThisBoard)/\(run.scoreGoalForBoard)")
                        Spacer()
                    }
                    HStack {
                        Text("shuffles: \(run.shufflesRemaining)  moveFrac: \(String(format: "%.2f", run.pendingMoveFraction))")
                        Spacer()
                    }
                    HStack {
                        Text("inventory: H\(run.inventory.hints) W\(run.inventory.wildcards) U\(run.inventory.undos)")
                        Spacer()
                    }
                    HStack {
                        Text("activePerks: \(run.activePerks.map { $0.rawValue }.joined(separator: ","))")
                        Spacer()
                    }
                }
            }
            .font(.caption.monospaced())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ParchmentTheme.Palette.ink.opacity(0.25), lineWidth: 1)
                    )
            )
            .foregroundStyle(ParchmentTheme.Palette.ink)
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

    private func hudPill(title: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.parchmentRounded(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(ParchmentTheme.Palette.slate)
            Text(value)
                .font(.parchmentRounded(size: 22, weight: .heavy).monospacedDigit())
                .foregroundStyle(ParchmentTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(ParchmentTheme.Palette.white)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ParchmentTheme.Palette.ink, lineWidth: ParchmentTheme.Stroke.hud)
                )
        )
        .shadow(
            color: ParchmentTheme.Palette.ink.opacity(ParchmentTheme.Shadow.hud.opacity),
            radius: ParchmentTheme.Shadow.hud.radius,
            x: ParchmentTheme.Shadow.hud.x,
            y: ParchmentTheme.Shadow.hud.y
        )
        .rotationEffect(.degrees(title == "Board" ? -1.4 : 1.1))
    }

    private func toyLabel(_ text: String, fill: Color, stroke: Color) -> some View {
        Text(text)
            .font(.parchmentRounded(size: 17, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 19)
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
            .shadow(
                color: ParchmentTheme.Palette.ink.opacity(0.16),
                radius: 5,
                x: 0,
                y: 8
            )
            .overlay(
                RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button - 16, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4.5)
            )
    }
}

// MARK: - Pause sheet

private struct PauseSheet: View {
    let onResume: () -> Void
    let onRestartRun: () -> Void
    let onQuitRun: () -> Void
    @State private var showSettings: Bool = false
    @State private var showRestartConfirmation: Bool = false

    var body: some View {
        VStack(spacing: ParchmentTheme.Spacing.lg) {
            Text("Paused")
                .font(.parchmentRounded(size: 28, weight: .heavy))
                .foregroundStyle(ParchmentTheme.Palette.ink)
                .padding(.top, ParchmentTheme.Spacing.lg)

            Divider()

            VStack(spacing: ParchmentTheme.Spacing.md) {
                pauseButton(
                    "Resume",
                    fill: ParchmentTheme.Palette.objectiveGreen,
                    stroke: ParchmentTheme.Palette.objectiveGreenText,
                    action: onResume
                )
                pauseButton(
                    "Settings",
                    fill: ParchmentTheme.Palette.footerBlue,
                    stroke: ParchmentTheme.Palette.footerBlueStroke,
                    action: { showSettings = true }
                )
                pauseButton(
                    "Restart Run",
                    fill: ParchmentTheme.Palette.footerYellow,
                    stroke: ParchmentTheme.Palette.footerYellowStroke,
                    action: { showRestartConfirmation = true }
                )
                pauseButton(
                    "Quit Run",
                    fill: ParchmentTheme.Palette.footerRed,
                    stroke: ParchmentTheme.Palette.footerRedStroke,
                    action: onQuitRun
                )
            }

            Spacer()
        }
        .padding(.horizontal, ParchmentTheme.Spacing.xl)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(SettingsStore.shared)
        }
        .alert("Restart Run?", isPresented: $showRestartConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restart") {
                onRestartRun()
            }
        } message: {
            Text("You’ll lose current progress for this run.")
        }
    }

    private func pauseButton(_ title: String, fill: Color, stroke: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.parchmentRounded(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: ParchmentTheme.Radius.button, style: .continuous)
                                .stroke(stroke, lineWidth: ParchmentTheme.Stroke.button)
                        )
                )
        }
        .buttonStyle(.plain)
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

private struct FloatingScorePop: View {
    let text: String
    let rise: CGFloat
    let duration: TimeInterval
    let onFinish: () -> Void

    @State private var animateOut = false

    var body: some View {
        Text(text)
            .font(.parchmentRounded(size: 28, weight: .heavy))
            .foregroundStyle(ParchmentTheme.Palette.objectiveGreenText)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(ParchmentTheme.Palette.white.opacity(0.94))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(ParchmentTheme.Palette.objectiveGreen, lineWidth: 2)
                    )
            )
            .shadow(color: ParchmentTheme.Palette.ink.opacity(0.15), radius: 4, x: 0, y: 2)
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
    let boardIndex: Int
    let templateDisplayName: String
    let hasStones: Bool
    let isBoss: Bool

    private var badges: [String] {
        var items: [String] = ["FREE PICK"]
        if hasStones { items.append("STONES") }
        if isBoss { items.append("BOSS") }
        return items
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("ACT \(currentAct) · BOARD \(boardIndex)")
                .font(.parchmentRounded(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(ParchmentTheme.Palette.slate)

            Text(templateDisplayName)
                .font(.parchmentRounded(size: 26, weight: .heavy))
                .foregroundStyle(ParchmentTheme.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if !badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(.parchmentRounded(size: 10, weight: .heavy))
                            .tracking(0.7)
                            .foregroundStyle(ParchmentTheme.Palette.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ParchmentTheme.Palette.white.opacity(0.9))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(ParchmentTheme.Palette.ink.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ParchmentTheme.Palette.paperBase.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ParchmentTheme.Palette.ink.opacity(0.36), lineWidth: 1.6)
                )
        )
        .shadow(color: ParchmentTheme.Palette.ink.opacity(0.16), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
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

#Preview {
    GameScreen(
        milestoneTracker: MilestoneTracker(),
        onQuitToMenu: {}
    )
}
