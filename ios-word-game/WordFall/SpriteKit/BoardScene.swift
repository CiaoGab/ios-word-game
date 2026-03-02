import SpriteKit

final class BoardScene: SKScene {
    var onSubmitPath: (([Int]) -> Void)?
    var onRequestBoard: (() -> [Tile?])?
    /// Called at the start of every touch (touchesBegan), before input-lock checks.
    var onAnyTouch: (() -> Void)?
    /// Called whenever the active drag path changes length (0 when cleared).
    var onPathLengthChanged: ((Int) -> Void)?

    var inputLocked: Bool = false

    private var layout: BoardLayout
    private var tileNodes: [UUID: TileNode] = [:]
    private var tileIDForIndex: [Int: UUID] = [:]
    private let boardBackdrop = SKShapeNode()
    private let boardInset = SKShapeNode()
    private let hintOverlayNode = SKNode()     // z=5; holds rings + polyline
    private let pathOverlay = SKShapeNode()    // z=6

    private var hintRings: [SKShapeNode] = []
    private var hintLineNode: SKShapeNode? = nil
    private let hintWaveKey = "hintWave"

    private var activePathIndices: [Int] = []
    private var currentHintPath: [Int]? = nil

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
        static let pauseAfter: TimeInterval = 0.60
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
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        for (tileID, node) in tileNodes {
            guard let index = tileIDForIndex.first(where: { $0.value == tileID })?.key else { continue }
            node.position = layout.position(for: index)
        }

        // Recompute hint line positions after tiles have moved.
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
            node.position = layout.position(for: index)
            node.zPosition = 10
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
            var actions: [(SKNode, SKAction)] = []

            for move in drops {
                guard let node = tileNodes[move.tileID] else { continue }
                tileIDForIndex[move.fromIndex] = nil
                tileIDForIndex[move.toIndex] = move.tileID
                let destination = layout.position(for: move.toIndex)
                actions.append((node, SKAction.move(to: destination, duration: 0.18)))
            }

            runNodeActions(actions, fallbackDuration: 0.08) {
                completion()
            }

        case .spawn(let spawns):
            var actions: [(SKNode, SKAction)] = []

            for spawn in spawns {
                let node = TileNode(tile: spawn.tile, size: layout.tileSize)
                let destination = layout.position(for: spawn.toIndex)
                let pitch = layout.tileSize + layout.spacing
                node.position = CGPoint(x: destination.x, y: destination.y + (pitch * CGFloat(spawn.spawnRowOffset)))
                node.alpha = 0
                node.setScale(0.8)
                node.zPosition = 10
                addChild(node)

                tileNodes[spawn.tile.id] = node
                tileIDForIndex[spawn.toIndex] = spawn.tile.id

                let action = SKAction.group([
                    SKAction.move(to: destination, duration: 0.2),
                    SKAction.fadeIn(withDuration: 0.14),
                    SKAction.scale(to: 1.0, duration: 0.2)
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

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        applyHint(nil)   // clear hint visuals immediately on any touch
        onAnyTouch?()
        guard !inputLocked, let point = touches.first?.location(in: self) else {
            clearActivePath()
            return
        }

        startPathIfNeeded(at: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !inputLocked, let point = touches.first?.location(in: self) else {
            return
        }

        extendPathIfNeeded(at: point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { clearActivePath() }
        guard !inputLocked else { return }
        guard activePathIndices.count >= 3 else { return }
        onSubmitPath?(activePathIndices)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearActivePath()
    }

    private func startPathIfNeeded(at point: CGPoint) {
        guard
            let index = layout.index(at: point),
            tileIDForIndex[index] != nil
        else {
            clearActivePath()
            return
        }

        activePathIndices = [index]
        updatePathUI()
    }

    private func extendPathIfNeeded(at point: CGPoint) {
        guard !activePathIndices.isEmpty else { return }
        guard let index = layout.index(at: point), tileIDForIndex[index] != nil else {
            return
        }

        guard let lastIndex = activePathIndices.last else { return }
        if index == lastIndex { return }

        // Backtrack: dragging onto the second-to-last tile pops the last tile.
        if activePathIndices.count >= 2 && index == activePathIndices[activePathIndices.count - 2] {
            activePathIndices.removeLast()
            Haptics.selectionStep()
            updatePathUI()
            return
        }

        // Forbid reusing any other tile already in the path.
        if activePathIndices.contains(index) {
            return
        }

        guard activePathIndices.count < 6 else { return }
        guard isAdjacent4(lastIndex, index) else { return }

        activePathIndices.append(index)
        Haptics.selectionStep()
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
            onPathLengthChanged?(activePathIndices.count)
            return
        }

        let path = CGMutablePath()
        for (offset, index) in activePathIndices.enumerated() {
            let point = layout.position(for: index)
            if offset == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        pathOverlay.path = path
        onPathLengthChanged?(activePathIndices.count)
    }

    private func isAdjacent4(_ a: Int, _ b: Int) -> Bool {
        let rowA = a / layout.cols, colA = a % layout.cols
        let rowB = b / layout.cols, colB = b % layout.cols
        return abs(rowA - rowB) + abs(colA - colB) == 1
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
        let positions = path.map { layout.position(for: $0) }

        // Per-tile rings.
        let ringRadius = layout.tileSize * 0.5 + 4
        for pos in positions {
            let ring = SKShapeNode(circleOfRadius: ringRadius)
            ring.position = pos
            ring.fillColor = .clear
            ring.strokeColor = ParchmentTheme.Palette.tileHint
            ring.lineWidth = 3
            ring.alpha = HintAnim.alphaLow
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

        startHintWave()
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
    ///   t=0.36 + 0.28 + 0.60 = t=1.24 → loop (≈ 1.2 s cycle)
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
        boardBackdrop.strokeColor = ParchmentTheme.Palette.boardDashSK
        boardBackdrop.lineWidth = ParchmentTheme.Stroke.boardDashed
        boardBackdrop.lineJoin = .round
        addChild(boardBackdrop)

        boardInset.zPosition = 2
        boardInset.fillColor = .clear
        boardInset.strokeColor = ParchmentTheme.Palette.boardStrokeSK
        boardInset.lineWidth = ParchmentTheme.Stroke.boardContainer
        boardInset.lineJoin = .round
        boardInset.glowWidth = 0.5
        addChild(boardInset)
    }

    private func configurePathOverlay() {
        pathOverlay.zPosition = 6
        pathOverlay.strokeColor = SKColor(red: 0.16, green: 0.44, blue: 0.84, alpha: 0.52)
        pathOverlay.lineWidth = 8
        pathOverlay.lineCap = .round
        pathOverlay.lineJoin = .round
        pathOverlay.glowWidth = 2
        pathOverlay.fillColor = .clear
        addChild(pathOverlay)
    }

    private func updateBoardBackdropPath() {
        let outerInset = layout.spacing * 0.5
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
        boardBackdrop.path = outerPath.copy(dashingWithPhase: 0, lengths: [8, 6])

        let innerRect = outerRect.insetBy(dx: 10, dy: 10)
        boardInset.path = CGPath(
            roundedRect: innerRect,
            cornerWidth: max(12, corner - 4),
            cornerHeight: max(12, corner - 4),
            transform: nil
        )
    }
}
