import SpriteKit

final class BoardScene: SKScene {
    var onRequestBoard: (() -> [Tile?])?
    /// Called whenever the tap selection changes. Passes the current path indices (empty when cleared).
    var onSelectionChanged: (([Int]) -> Void)?
    /// Called when wildcardPlacingMode is true and the player taps a valid tile.
    /// The controller should convert that tile index to a wildcard and reset the flag.
    var onWildcardPlace: ((Int) -> Void)?

    var inputLocked: Bool = false
    /// When true, the next tile tap places a wildcard instead of extending the selection.
    var wildcardPlacingMode: Bool = false

    private var layout: BoardLayout
    private var boardTemplate: BoardTemplate?
    private var tileNodes: [UUID: TileNode] = [:]
    private var tileIDForIndex: [Int: UUID] = [:]
    private let boardBackdrop = SKShapeNode()
    private let boardInset = SKShapeNode()
    private let hintOverlayNode = SKNode()     // z=5; holds rings + polyline
    private let pathOverlay = SKShapeNode()    // z=6

    private var hintRings: [SKShapeNode] = []
    private var hintLineNode: SKShapeNode? = nil
    private let hintWaveKey = "hintWave"
    private let maxSelectionLength = Resolver.maxWordLen

    private var activePathIndices: [Int] = []
    private var currentHintPath: [Int]? = nil
    private var settingsObserver: NSObjectProtocol?

    // MARK: - Hint animation constants
    // Tune these values to adjust the wave feel without touching logic.
    private enum HintAnim {
        /// Ring scale at pulse peak.
        static let pulseScale: CGFloat      = 1.08
        /// Ring alpha at rest (between pulses).
        static let alphaLow: CGFloat        = 0.60
        /// Ring alpha at pulse peak.
        static let alphaHigh: CGFloat       = 1.00
        /// Duration of the scale-up (or scale-down) half of one pulse. Full pulse = halfPulse × 2.
        static let halfPulse: TimeInterval  = 0.14
        /// Delay before each successive ring fires its pulse in the wave.
        static let stagger: TimeInterval    = 0.18
        /// Rest pause after the last ring's pulse before the wave repeats.
        static let pauseAfter: TimeInterval = 0.56
    }

    init(rows: Int, cols: Int, size: CGSize) {
        self.layout = BoardLayout(rows: rows, cols: cols)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .clear
        configureBoardBackdrop()
        configureHintOverlayNode()
        configurePathOverlay()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAccessibilitySettings()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        updateLayout(for: size)
        if let board = onRequestBoard?() {
            renderBoard(tiles: board)
        }
    }

    func updateLayout(for size: CGSize) {
        self.size = size
        layout.update(sceneSize: size)
        updateBoardBackdropPath()
        updatePathUI()
        refreshTileTransforms()

        // Recompute hint line positions after tiles have moved.
        applyHint(currentHintPath)
    }

    func configureGrid(rows: Int, cols: Int) {
        guard rows > 0, cols > 0 else { return }
        guard layout.rows != rows || layout.cols != cols else { return }
        layout = BoardLayout(rows: rows, cols: cols)
        clearActivePath()
        clearHintOverlay()
        currentHintPath = nil
        updateLayout(for: size)
    }

    func configureTemplate(_ template: BoardTemplate) {
        boardTemplate = template
        refreshTileTransforms()
        updatePathUI()
        applyHint(currentHintPath)
    }

    func renderBoard(tiles: [Tile?]) {
        for node in tileNodes.values {
            node.removeFromParent()
        }
        tileNodes.removeAll()
        tileIDForIndex.removeAll()

        for index in tiles.indices {
            guard let tile = tiles[index] else { continue }
            let node = TileNode(tile: tile, size: layout.tileSize)
            node.zPosition = 10
            applyTransform(to: node, at: index)
            addChild(node)
            tileNodes[tile.id] = node
            tileIDForIndex[index] = tile.id
        }

        clearActivePath()
        clearHintOverlay()
        currentHintPath = nil
    }

    // MARK: - Event playback

    func play(events: [GameEvent], completion: @escaping () -> Void) {
        playNext(events: events, at: 0, completion: completion)
    }

    private func playNext(events: [GameEvent], at index: Int, completion: @escaping () -> Void) {
        guard index < events.count else {
            completion()
            return
        }

        run(event: events[index]) { [weak self] in
            guard let self else { return }
            self.playNext(events: events, at: index + 1, completion: completion)
        }
    }

    private func run(event: GameEvent, completion: @escaping () -> Void) {
        switch event {
        case .lockBreak(let indices):
            SoundManager.shared.playLockBreak()
            Haptics.lockBreak()
            var actions: [(SKNode, SKAction)] = []

            for boardIndex in indices {
                guard
                    let tileID = tileIDForIndex[boardIndex],
                    let node = tileNodes[tileID]
                else {
                    continue
                }
                node.setFreshness(.freshUnlocked)
                node.playLockBreakAnimation()
                actions.append((node, SKAction.wait(forDuration: 0.14)))
            }

            runNodeActions(actions, fallbackDuration: 0.08) {
                completion()
            }

        case .clear(let clear):
            SoundManager.shared.playClear()
            var actions: [(SKNode, SKAction)] = []

            for boardIndex in clear.indices {
                guard
                    let tileID = tileIDForIndex[boardIndex],
                    let node = tileNodes[tileID]
                else {
                    continue
                }
                node.setMatched(true)
                tileIDForIndex[boardIndex] = nil
                tileNodes[tileID] = nil
                let action = SKAction.sequence([
                    SKAction.wait(forDuration: 0.06),
                    SKAction.group([
                        SKAction.scale(to: 0.12, duration: 0.16),
                        SKAction.fadeOut(withDuration: 0.16)
                    ]),
                    SKAction.removeFromParent()
                ])
                actions.append((node, action))
            }

            runNodeActions(actions, fallbackDuration: 0.12) {
                completion()
            }

        case .drop(let drops):
            SoundManager.shared.playCascade()
            var actions: [(SKNode, SKAction)] = []

            for move in drops {
                guard let node = tileNodes[move.tileID] else { continue }
                tileIDForIndex[move.fromIndex] = nil
                tileIDForIndex[move.toIndex] = move.tileID
                let destination = displayPosition(for: move.toIndex)
                actions.append((node, SKAction.move(to: destination, duration: 0.18)))
            }

            runNodeActions(actions, fallbackDuration: 0.08) {
                completion()
            }

        case .spawn(let spawns):
            SoundManager.shared.playCascade()
            var actions: [(SKNode, SKAction)] = []

            for spawn in spawns {
                let node = TileNode(tile: spawn.tile, size: layout.tileSize)
                let destination = displayPosition(for: spawn.toIndex)
                let pitch = layout.tileSize + layout.spacing
                node.position = CGPoint(x: destination.x, y: destination.y + (pitch * CGFloat(spawn.spawnRowOffset)))
                node.alpha = 0
                node.zPosition = 10
                applyTransform(to: node, at: spawn.toIndex, preserveScale: false)
                node.position = CGPoint(x: destination.x, y: destination.y + (pitch * CGFloat(spawn.spawnRowOffset)))
                node.setScale(node.xScale * 0.8)
                addChild(node)

                tileNodes[spawn.tile.id] = node
                tileIDForIndex[spawn.toIndex] = spawn.tile.id

                let action = SKAction.group([
                    SKAction.move(to: destination, duration: 0.2),
                    SKAction.fadeIn(withDuration: 0.14),
                    SKAction.scale(to: tileScale(for: spawn.toIndex), duration: 0.2)
                ])
                actions.append((node, action))
            }

            runNodeActions(actions, fallbackDuration: 0.08) {
                completion()
            }

        }
    }

    private func runNodeActions(_ nodeActions: [(SKNode, SKAction)], fallbackDuration: TimeInterval, completion: @escaping () -> Void) {
        guard !nodeActions.isEmpty else {
            run(SKAction.wait(forDuration: fallbackDuration), completion: completion)
            return
        }

        var remaining = nodeActions.count
        for (node, action) in nodeActions {
            node.run(action) {
                remaining -= 1
                if remaining == 0 {
                    completion()
                }
            }
        }
    }

    // MARK: - Touch handling (tap-to-select)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !inputLocked, let point = touches.first?.location(in: self) else { return }
        handleTap(at: point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // No-op: tap-based selection is not interrupted by cancellation.
    }

    // MARK: - Tap selection logic

    private func handleTap(at point: CGPoint) {
        guard let index = layout.index(at: point), isSelectableIndex(index) else {
            // Tapped outside the board — ignore; use dedicated clear action instead.
            return
        }

        // Wildcard placing mode: intercept tap and delegate to controller.
        if wildcardPlacingMode {
            wildcardPlacingMode = false
            onWildcardPlace?(index)
            return
        }

        if let selectedOffset = activePathIndices.firstIndex(of: index) {
            activePathIndices.remove(at: selectedOffset)
            Haptics.selectionStep()
            SoundManager.shared.playTileDeselect()
        } else if activePathIndices.count < maxSelectionLength {
            activePathIndices.append(index)
            Haptics.selectionStep()
            SoundManager.shared.playTileTap()
        } else {
            Haptics.notifyWarning()
        }

        updatePathUI()
    }

    private func isSelectableIndex(_ index: Int) -> Bool {
        guard let board = onRequestBoard?() else { return false }
        guard index >= 0, index < board.count else { return false }
        guard let tile = board[index] else { return false }
        return tile.isLetterTile
    }

    // MARK: - Public selection control

    /// Clears the current tile selection (called by the controller after submit or reset).
    func clearSelection() {
        clearActivePath()
    }

    /// Sets the current selection programmatically (used for hint powerups).
    func setSelection(indices: [Int]) {
        var seen: Set<Int> = []
        var unique: [Int] = []
        for index in indices where !seen.contains(index) {
            seen.insert(index)
            unique.append(index)
        }
        let clamped = Array(unique.prefix(maxSelectionLength))
        activePathIndices = clamped.filter { isSelectableIndex($0) }
        updatePathUI()
    }

    /// Removes the last tile from the selection (backtrack one step).
    func popLastTile() {
        guard !activePathIndices.isEmpty else { return }
        activePathIndices.removeLast()
        Haptics.selectionStep()
        SoundManager.shared.playTileDeselect()
        updatePathUI()
    }

    private func clearActivePath() {
        activePathIndices = []
        updatePathUI()
    }

    private func updatePathUI() {
        let selected = Set(activePathIndices)
        for (index, tileID) in tileIDForIndex {
            guard let node = tileNodes[tileID] else { continue }
            node.setHighlighted(selected.contains(index))
        }

        guard activePathIndices.count >= 2 else {
            pathOverlay.path = nil
            onSelectionChanged?(activePathIndices)
            return
        }

        let path = CGMutablePath()
        for (offset, index) in activePathIndices.enumerated() {
            let point = displayPosition(for: index)
            if offset == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        pathOverlay.path = path
        onSelectionChanged?(activePathIndices)
    }

    // MARK: - Hint rendering

    func applyHint(_ path: [Int]?) {
        currentHintPath = path
        clearHintOverlay()

        let hintedSet = Set(path ?? [])
        for (index, tileID) in tileIDForIndex {
            guard let node = tileNodes[tileID] else { continue }
            node.setHinted(hintedSet.contains(index))
        }

        guard let path, path.count == 3 else { return }
        let positions = path.map { displayPosition(for: $0) }

        // Per-tile rings.
        let ringRadius = layout.tileSize * 0.5 + 4
        for pos in positions {
            let ring = SKShapeNode(circleOfRadius: ringRadius)
            ring.position = pos
            ring.fillColor = .clear
            ring.strokeColor = ParchmentTheme.Palette.tileHint
            ring.lineWidth = 3
            ring.alpha = AppSettings.reduceMotion ? HintAnim.alphaHigh : HintAnim.alphaLow
            hintOverlayNode.addChild(ring)
            hintRings.append(ring)
        }

        // Connecting polyline.
        let linePath = CGMutablePath()
        for (i, pos) in positions.enumerated() {
            if i == 0 { linePath.move(to: pos) } else { linePath.addLine(to: pos) }
        }
        let line = SKShapeNode(path: linePath)
        line.strokeColor = ParchmentTheme.Palette.tileHint.withAlphaComponent(0.30)
        line.lineWidth = 3
        line.lineCap = .round
        line.lineJoin = .round
        line.fillColor = .clear
        hintOverlayNode.addChild(line)
        hintLineNode = line

        if !AppSettings.reduceMotion {
            startHintWave()
        }
    }

    /// Stops the wave and removes all hint overlay children without touching tile hint state.
    private func clearHintOverlay() {
        hintOverlayNode.removeAction(forKey: hintWaveKey)
        hintOverlayNode.removeAllChildren()
        hintRings = []
        hintLineNode = nil
    }

    /// Launches the staggered ring-pulse wave and repeats it every ~1.2 s.
    ///
    /// Timing breakdown (all durations tunable via `HintAnim`):
    ///   t=0.00  ring0 fires  ─┐
    ///   t=0.18  ring1 fires   │ each pulse = halfPulse*2 = 0.28 s
    ///   t=0.36  ring2 fires  ─┘
    ///   t=0.36 + 0.28 + 0.56 = t=1.20 → loop
    private func startHintWave() {
        guard hintRings.count == 3 else { return }
        let ring0 = hintRings[0]
        let ring1 = hintRings[1]
        let ring2 = hintRings[2]

        let wave = SKAction.sequence([
            SKAction.run { ring0.run(BoardScene.pulseRingAction()) },
            SKAction.wait(forDuration: HintAnim.stagger),
            SKAction.run { ring1.run(BoardScene.pulseRingAction()) },
            SKAction.wait(forDuration: HintAnim.stagger),
            SKAction.run { ring2.run(BoardScene.pulseRingAction()) },
            SKAction.wait(forDuration: HintAnim.halfPulse * 2 + HintAnim.pauseAfter)
        ])
        hintOverlayNode.run(SKAction.repeatForever(wave), withKey: hintWaveKey)
    }

    /// One scale + alpha pulse for a single ring. Static so closures capture no `self`.
    private static func pulseRingAction() -> SKAction {
        let half = HintAnim.halfPulse
        let up = SKAction.group([
            SKAction.scale(to: HintAnim.pulseScale, duration: half),
            SKAction.fadeAlpha(to: HintAnim.alphaHigh, duration: half)
        ])
        let down = SKAction.group([
            SKAction.scale(to: 1.0, duration: half),
            SKAction.fadeAlpha(to: HintAnim.alphaLow, duration: half)
        ])
        return SKAction.sequence([up, down])
    }

    private func configureHintOverlayNode() {
        hintOverlayNode.zPosition = 5
        addChild(hintOverlayNode)
    }

    private func configureBoardBackdrop() {
        boardBackdrop.zPosition = 1
        boardBackdrop.fillColor = .clear
        boardBackdrop.lineJoin = .round
        addChild(boardBackdrop)

        boardInset.zPosition = 2
        boardInset.fillColor = .clear
        boardInset.lineJoin = .round
        boardInset.glowWidth = 0
        addChild(boardInset)
        applyAccessibilitySettings()
    }

    private func configurePathOverlay() {
        pathOverlay.zPosition = 6
        pathOverlay.strokeColor = StitchTheme.Tile.selectedStroke.withAlphaComponent(0.72)
        pathOverlay.lineWidth = AppSettings.highContrast ? 9 : 7
        pathOverlay.lineCap = .round
        pathOverlay.lineJoin = .round
        pathOverlay.glowWidth = AppSettings.reduceMotion ? 0 : 3
        pathOverlay.fillColor = .clear
        addChild(pathOverlay)
    }

    private func applyAccessibilitySettings() {
        boardBackdrop.strokeColor = ParchmentTheme.Palette.boardDashSK.withAlphaComponent(
            AppSettings.highContrast ? 0.18 : 0.08
        )
        boardBackdrop.lineWidth = AppSettings.highContrast ? 1.4 : 0.9
        boardInset.strokeColor = ParchmentTheme.Palette.boardInnerStrokeSK.withAlphaComponent(
            AppSettings.highContrast ? 0.12 : 0.05
        )
        boardInset.lineWidth = AppSettings.highContrast ? 1.0 : 0.6
        boardInset.isHidden = !AppSettings.highContrast
        pathOverlay.lineWidth = AppSettings.highContrast ? 9 : 7
        pathOverlay.glowWidth = AppSettings.reduceMotion ? 0 : 3

        for node in tileNodes.values {
            node.refreshTheme()
        }

        applyHint(currentHintPath)
    }

    private func updateBoardBackdropPath() {
        let outerInset = layout.spacing * 0.45
        let outerRect = CGRect(
            x: -(layout.boardSize.width / 2) - outerInset,
            y: -(layout.boardSize.height / 2) - outerInset,
            width: layout.boardSize.width + (outerInset * 2),
            height: layout.boardSize.height + (outerInset * 2)
        )
        let corner = max(16, layout.tileSize * 0.28)
        let outerPath = CGPath(
            roundedRect: outerRect,
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )
        boardBackdrop.path = outerPath.copy(dashingWithPhase: 0, lengths: [4, 14])

        let innerRect = outerRect.insetBy(dx: 10, dy: 10)
        boardInset.path = CGPath(
            roundedRect: innerRect,
            cornerWidth: max(12, corner - 4),
            cornerHeight: max(12, corner - 4),
            transform: nil
        )
    }

    private func refreshTileTransforms() {
        for (index, tileID) in tileIDForIndex {
            guard let node = tileNodes[tileID] else { continue }
            applyTransform(to: node, at: index)
        }
    }

    private func applyTransform(to node: SKNode, at index: Int, preserveScale: Bool = true) {
        node.position = displayPosition(for: index)
        let scale = tileScale(for: index)
        if preserveScale {
            node.setScale(scale)
        } else {
            node.xScale = scale
            node.yScale = scale
        }
    }

    private func displayPosition(for index: Int) -> CGPoint {
        let base = layout.position(for: index)
        guard let boardTemplate else { return base }

        switch boardTemplate.visualStyle {
        case .standard:
            return base
        case .triplePoolsBalanced:
            switch boardTemplate.regionID(for: index) {
            case 0:
                return CGPoint(x: base.x - 4, y: base.y + 4)
            case 1:
                return CGPoint(x: base.x + 4, y: base.y + 4)
            case 2:
                return CGPoint(x: base.x, y: base.y - 4)
            default:
                return base
            }
        }
    }

    private func tileScale(for index: Int) -> CGFloat {
        guard let boardTemplate else { return 1.0 }

        switch boardTemplate.visualStyle {
        case .standard:
            return 1.0
        case .triplePoolsBalanced:
            switch boardTemplate.regionID(for: index) {
            case 0, 1:
                return 0.96
            case 2:
                return 1.08
            default:
                return 1.0
            }
        }
    }
}
