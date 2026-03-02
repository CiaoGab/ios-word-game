import SpriteKit

final class TileNode: SKShapeNode {
    let tileID: UUID

    private let letterLabel: SKLabelNode
    private let valueLabel: SKLabelNode
    private let depthNode: SKShapeNode
    private let badgeNode: SKShapeNode
    private let badgeLabel: SKLabelNode

    private var freshness: TileFreshness
    private var isHighlightedState = false
    private var isHintedState = false
    private var isMatchedState = false

    init(tile: Tile, size: CGFloat) {
        self.tileID = tile.id
        self.freshness = tile.freshness

        letterLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        depthNode = SKShapeNode()
        badgeNode = SKShapeNode()
        badgeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")

        super.init()

        let corner = max(ParchmentTheme.Radius.tile, size * 0.28)
        let rect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        let dropOffset = max(5, size * 0.14)

        depthNode.path = CGPath(
            roundedRect: rect.offsetBy(dx: 0, dy: -dropOffset),
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )
        depthNode.fillColor = ParchmentTheme.Palette.tileDepth
        depthNode.strokeColor = .clear
        depthNode.zPosition = -1
        addChild(depthNode)

        path = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        lineWidth = ParchmentTheme.Stroke.tile
        lineJoin = .round
        zPosition = 10

        letterLabel.text = String(tile.letter)
        letterLabel.fontSize = size * 0.47
        letterLabel.verticalAlignmentMode = .center
        letterLabel.horizontalAlignmentMode = .center
        letterLabel.position = CGPoint(x: 0, y: -size * 0.01)
        letterLabel.zPosition = 2
        addChild(letterLabel)

        valueLabel.text = "\(LetterValues.value(for: tile.letter))"
        valueLabel.fontSize = max(8, size * 0.19)
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.position = CGPoint(x: size * 0.34, y: -size * 0.36)
        valueLabel.zPosition = 2
        addChild(valueLabel)

        let badgeSize = max(12, size * 0.28)
        badgeNode.path = CGPath(
            ellipseIn: CGRect(x: -badgeSize / 2, y: -badgeSize / 2, width: badgeSize, height: badgeSize),
            transform: nil
        )
        badgeNode.lineWidth = ParchmentTheme.Stroke.badge
        badgeNode.zPosition = 3
        badgeNode.position = CGPoint(x: size * 0.32, y: size * 0.32)
        addChild(badgeNode)

        badgeLabel.fontSize = max(8, size * 0.15)
        badgeLabel.verticalAlignmentMode = .center
        badgeLabel.horizontalAlignmentMode = .center
        badgeLabel.position = CGPoint(x: 0, y: -badgeSize * 0.06)
        badgeLabel.zPosition = 4
        badgeNode.addChild(badgeLabel)

        updateAppearance()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setHighlighted(_ highlighted: Bool) {
        isHighlightedState = highlighted
        if highlighted {
            removeAction(forKey: "hintPulse")
        }
        updateAppearance()
    }

    func setHinted(_ hinted: Bool) {
        isHintedState = hinted
        removeAction(forKey: "hintPulse")

        if hinted {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.07, duration: 0.32),
                SKAction.scale(to: 0.98, duration: 0.32)
            ])
            run(SKAction.repeatForever(pulse), withKey: "hintPulse")
        } else {
            run(SKAction.scale(to: 1.0, duration: 0.08), withKey: "hintPulseReset")
        }

        updateAppearance()
    }

    func setMatched(_ matched: Bool) {
        isMatchedState = matched
        updateAppearance()

        if matched {
            run(SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.08)
            ]), withKey: "matchPulse")
        }
    }

    func setFreshness(_ freshness: TileFreshness) {
        self.freshness = freshness
        updateAppearance()
    }

    func playLockBreakAnimation() {
        let shake = SKAction.sequence([
            SKAction.rotate(byAngle: -0.06, duration: 0.04),
            SKAction.rotate(byAngle: 0.12, duration: 0.08),
            SKAction.rotate(toAngle: 0.0, duration: 0.05)
        ])
        let pop = SKAction.sequence([
            SKAction.scale(to: 1.22, duration: 0.06),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])

        run(shake, withKey: "lockBreakShake")
        badgeNode.run(pop, withKey: "lockBreakPop")
    }

    private func updateAppearance() {
        if isMatchedState {
            fillColor = ParchmentTheme.Palette.tileMatchFill
            strokeColor = ParchmentTheme.Palette.tileMatchStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileMatchText
            valueLabel.fontColor = ParchmentTheme.Palette.tileMatchText.withAlphaComponent(0.62)
            depthNode.fillColor = SKColor(red: 0.94, green: 0.69, blue: 0.25, alpha: 1.0)
            badgeNode.isHidden = true
            return
        }

        if isHighlightedState {
            fillColor = ParchmentTheme.Palette.tileSelectedFill
            strokeColor = ParchmentTheme.Palette.tileSelectedStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileSelectedText
            valueLabel.fontColor = ParchmentTheme.Palette.tileSelectedText.withAlphaComponent(0.60)
            depthNode.fillColor = SKColor(red: 0.40, green: 0.84, blue: 0.91, alpha: 1.0)
            updateBadgeAppearance()
            return
        }

        switch freshness {
        case .normal:
            fillColor = ParchmentTheme.Palette.tileFill
            strokeColor = isHintedState
                ? ParchmentTheme.Palette.tileHint
                : ParchmentTheme.Palette.tileStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileText
            valueLabel.fontColor = ParchmentTheme.Palette.tileValue
            depthNode.fillColor = ParchmentTheme.Palette.tileDepth

        case .freshLocked:
            fillColor = mixColor(
                ParchmentTheme.Palette.tileFill,
                with: SKColor(red: 0.68, green: 0.79, blue: 0.94, alpha: 1.0),
                fraction: 0.23
            )
            strokeColor = isHintedState
                ? ParchmentTheme.Palette.tileHint
                : SKColor(red: 0.30, green: 0.50, blue: 0.75, alpha: 1.0)
            letterLabel.fontColor = ParchmentTheme.Palette.tileText
            valueLabel.fontColor = ParchmentTheme.Palette.tileValue
            depthNode.fillColor = SKColor(red: 0.58, green: 0.72, blue: 0.90, alpha: 1.0)

        case .freshUnlocked:
            fillColor = mixColor(
                ParchmentTheme.Palette.tileFill,
                with: SKColor(red: 0.79, green: 0.80, blue: 0.82, alpha: 1.0),
                fraction: 0.18
            )
            strokeColor = isHintedState
                ? ParchmentTheme.Palette.tileHint
                : SKColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1.0)
            letterLabel.fontColor = ParchmentTheme.Palette.tileText
            valueLabel.fontColor = ParchmentTheme.Palette.tileValue
            depthNode.fillColor = SKColor(red: 0.74, green: 0.76, blue: 0.79, alpha: 1.0)
        }

        updateBadgeAppearance()
    }

    private func updateBadgeAppearance() {
        switch freshness {
        case .normal:
            badgeNode.isHidden = true

        case .freshLocked:
            badgeNode.isHidden = false
            badgeNode.fillColor = ParchmentTheme.Palette.tileLockedBadgeFill
            badgeNode.strokeColor = ParchmentTheme.Palette.tileLockedBadgeStroke
            badgeLabel.fontColor = ParchmentTheme.Palette.tileLockedBadgeText
            badgeLabel.text = "L"

        case .freshUnlocked:
            badgeNode.isHidden = false
            badgeNode.fillColor = ParchmentTheme.Palette.tileUnlockedBadgeFill
            badgeNode.strokeColor = ParchmentTheme.Palette.tileUnlockedBadgeStroke
            badgeLabel.fontColor = ParchmentTheme.Palette.tileUnlockedBadgeText
            badgeLabel.text = "/"
        }
    }

    private func mixColor(_ base: SKColor, with overlay: SKColor, fraction: CGFloat) -> SKColor {
        let clamped = min(1.0, max(0.0, fraction))
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0
        var or: CGFloat = 0
        var og: CGFloat = 0
        var ob: CGFloat = 0
        var oa: CGFloat = 0
        base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        overlay.getRed(&or, green: &og, blue: &ob, alpha: &oa)

        return SKColor(
            red: br + ((or - br) * clamped),
            green: bg + ((og - bg) * clamped),
            blue: bb + ((ob - bb) * clamped),
            alpha: ba + ((oa - ba) * clamped)
        )
    }
}
