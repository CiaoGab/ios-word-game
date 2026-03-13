import SpriteKit

final class TileNode: SKShapeNode {
    let tileID: UUID

    private let letterLabel: SKLabelNode
    private let valueShadowLabel: SKLabelNode
    private let valueLabel: SKLabelNode
    private let valueBackgroundNode: SKShapeNode
    private let depthNode: SKShapeNode
    private let badgeNode: SKShapeNode
    private let badgeLabel: SKLabelNode
    private let infusionAccentNode: SKShapeNode
    private let infusionBadgeNode: SKShapeNode
    private let infusionBadgeLabel: SKLabelNode

    private var freshness: TileFreshness
    private var kind: TileKind
    private var infusion: TileInfusion
    private var isHighlightedState = false
    private var isHintedState = false
    private var isMatchedState = false

    init(tile: Tile, size: CGFloat) {
        self.tileID = tile.id
        self.freshness = tile.freshness
        self.kind = tile.kind
        self.infusion = tile.infusion

        letterLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueShadowLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueBackgroundNode = SKShapeNode()
        depthNode = SKShapeNode()
        badgeNode = SKShapeNode()
        badgeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        infusionAccentNode = SKShapeNode()
        infusionBadgeNode = SKShapeNode()
        infusionBadgeLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")

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

        let accentInset = max(2.2, size * 0.07)
        infusionAccentNode.path = CGPath(
            roundedRect: rect.insetBy(dx: accentInset, dy: accentInset),
            cornerWidth: max(8, corner - accentInset),
            cornerHeight: max(8, corner - accentInset),
            transform: nil
        )
        infusionAccentNode.fillColor = .clear
        infusionAccentNode.lineJoin = .round
        infusionAccentNode.lineWidth = ParchmentTheme.Stroke.tileInfusionAccent
        infusionAccentNode.zPosition = 1.5
        infusionAccentNode.isHidden = true
        addChild(infusionAccentNode)

        let infusionBadgeSize = CGSize(width: max(18, size * 0.35), height: max(12, size * 0.22))
        infusionBadgeNode.path = CGPath(
            roundedRect: CGRect(
                x: -infusionBadgeSize.width / 2,
                y: -infusionBadgeSize.height / 2,
                width: infusionBadgeSize.width,
                height: infusionBadgeSize.height
            ),
            cornerWidth: infusionBadgeSize.height * 0.5,
            cornerHeight: infusionBadgeSize.height * 0.5,
            transform: nil
        )
        infusionBadgeNode.lineWidth = 1.2
        infusionBadgeNode.zPosition = 3
        infusionBadgeNode.position = CGPoint(x: -size * 0.31, y: size * 0.32)
        infusionBadgeNode.isHidden = true
        addChild(infusionBadgeNode)

        infusionBadgeLabel.fontSize = max(7, size * 0.15)
        infusionBadgeLabel.verticalAlignmentMode = .center
        infusionBadgeLabel.horizontalAlignmentMode = .center
        infusionBadgeLabel.position = CGPoint(x: 0, y: -infusionBadgeSize.height * 0.05)
        infusionBadgeLabel.zPosition = 4
        infusionBadgeNode.addChild(infusionBadgeLabel)

        letterLabel.text = tile.kind == .wildcard ? "?" : String(tile.letter)
        letterLabel.fontSize = size * 0.47
        letterLabel.verticalAlignmentMode = .center
        letterLabel.horizontalAlignmentMode = .center
        letterLabel.position = CGPoint(x: 0, y: -size * 0.01)
        letterLabel.zPosition = 2
        addChild(letterLabel)

        let pointText = "\(LetterValues.value(for: tile.letter))"
        let valueCenter = CGPoint(x: size * 0.33, y: -size * 0.35)
        let chipW = max(22, size * 0.46)
        let chipH = max(15, size * 0.30)

        valueBackgroundNode.path = CGPath(
            roundedRect: CGRect(x: -chipW / 2, y: -chipH / 2, width: chipW, height: chipH),
            cornerWidth: chipH * 0.5,
            cornerHeight: chipH * 0.5,
            transform: nil
        )
        valueBackgroundNode.position = valueCenter
        valueBackgroundNode.fillColor = ParchmentTheme.Palette.tileValueShadow
        valueBackgroundNode.strokeColor = ParchmentTheme.Palette.tileStroke.withAlphaComponent(0.55)
        valueBackgroundNode.lineWidth = 1.2
        valueBackgroundNode.zPosition = 1.6
        addChild(valueBackgroundNode)

        valueShadowLabel.text = pointText
        valueShadowLabel.fontSize = max(11, size * 0.265)
        valueShadowLabel.verticalAlignmentMode = .center
        valueShadowLabel.horizontalAlignmentMode = .center
        valueShadowLabel.position = CGPoint(x: size * 0.338, y: -size * 0.362)
        valueShadowLabel.zPosition = 1.8
        addChild(valueShadowLabel)

        valueLabel.text = pointText
        valueLabel.fontSize = max(11, size * 0.265)
        valueLabel.verticalAlignmentMode = .center
        valueLabel.horizontalAlignmentMode = .center
        valueLabel.position = CGPoint(x: size * 0.33, y: -size * 0.35)
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
        removeAction(forKey: "hintPulseReset")

        if hinted && !AppSettings.reduceMotion {
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

    func refreshTheme() {
        lineWidth = ParchmentTheme.Stroke.tile
        badgeNode.lineWidth = ParchmentTheme.Stroke.badge
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

    func setKind(_ kind: TileKind) {
        self.kind = kind
        letterLabel.text = kind == .wildcard ? "?" : letterLabel.text
        updateAppearance()
    }

    func setInfusion(_ infusion: TileInfusion) {
        self.infusion = infusion
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
        letterLabel.isHidden = false
        valueLabel.isHidden = false
        valueShadowLabel.isHidden = false

        if kind == .stone {
            fillColor = mixColor(
                ParchmentTheme.Palette.tileFill,
                with: SKColor(red: 0.56, green: 0.58, blue: 0.60, alpha: 1.0),
                fraction: 0.64
            )
            strokeColor = SKColor(red: 0.31, green: 0.33, blue: 0.36, alpha: 1.0)
            lineWidth = max(ParchmentTheme.Stroke.tile, 3.2)
            depthNode.fillColor = SKColor(red: 0.42, green: 0.44, blue: 0.47, alpha: 1.0)
            letterLabel.isHidden = true
            valueLabel.isHidden = true
            valueShadowLabel.isHidden = true
            valueBackgroundNode.isHidden = true
            badgeNode.isHidden = true
            hideInfusionAccent()
            return
        } else {
            lineWidth = ParchmentTheme.Stroke.tile
            valueBackgroundNode.isHidden = false
        }

        if isMatchedState {
            fillColor = ParchmentTheme.Palette.tileMatchFill
            strokeColor = ParchmentTheme.Palette.tileMatchStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileMatchText
            setValueLabelColors(
                main: ParchmentTheme.Palette.tileMatchText.withAlphaComponent(0.78),
                shadow: ParchmentTheme.Palette.tileValueShadow.withAlphaComponent(0.68)
            )
            depthNode.fillColor = SKColor(red: 0.94, green: 0.69, blue: 0.25, alpha: 1.0)
            valueBackgroundNode.fillColor = ParchmentTheme.Palette.tileValueShadow.withAlphaComponent(0.7)
            valueBackgroundNode.strokeColor = ParchmentTheme.Palette.tileMatchStroke.withAlphaComponent(0.5)
            badgeNode.isHidden = true
            hideInfusionAccent()
            return
        }

        valueBackgroundNode.fillColor = ParchmentTheme.Palette.tileValueShadow
        valueBackgroundNode.strokeColor = ParchmentTheme.Palette.tileStroke.withAlphaComponent(0.55)

        // Wildcard override: purple fill with "?" glyph
        if kind == .wildcard && !isHighlightedState {
            fillColor = SKColor(red: 0.91, green: 0.83, blue: 0.99, alpha: 1.0)
            strokeColor = SKColor(red: 0.65, green: 0.32, blue: 0.88, alpha: 1.0)
            letterLabel.fontColor = SKColor(red: 0.50, green: 0.10, blue: 0.70, alpha: 1.0)
            setValueLabelColors(
                main: SKColor(red: 0.50, green: 0.10, blue: 0.70, alpha: 0.70),
                shadow: ParchmentTheme.Palette.tileValueShadow.withAlphaComponent(0.76)
            )
            depthNode.fillColor = SKColor(red: 0.75, green: 0.60, blue: 0.92, alpha: 1.0)
            badgeNode.isHidden = true
            updateInfusionAppearance()
            return
        }

        if isHighlightedState {
            fillColor = ParchmentTheme.Palette.tileSelectedFill
            strokeColor = ParchmentTheme.Palette.tileSelectedStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileSelectedText
            setValueLabelColors(
                main: ParchmentTheme.Palette.tileSelectedText.withAlphaComponent(0.84),
                shadow: ParchmentTheme.Palette.tileValueShadow.withAlphaComponent(0.80)
            )
            depthNode.fillColor = SKColor(red: 0.40, green: 0.84, blue: 0.91, alpha: 1.0)
            updateBadgeAppearance()
            updateInfusionAppearance()
            return
        }

        switch freshness {
        case .normal:
            fillColor = ParchmentTheme.Palette.tileFill
            strokeColor = isHintedState
                ? ParchmentTheme.Palette.tileHint
                : ParchmentTheme.Palette.tileStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileText
            setValueLabelColors(
                main: ParchmentTheme.Palette.tileValue,
                shadow: ParchmentTheme.Palette.tileValueShadow.withAlphaComponent(0.84)
            )
            depthNode.fillColor = ParchmentTheme.Palette.tileDepth

        case .freshLocked:
            fillColor = ParchmentTheme.Palette.tileFill
            strokeColor = isHintedState
                ? ParchmentTheme.Palette.tileHint
                : ParchmentTheme.Palette.tileStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileText
            setValueLabelColors(
                main: ParchmentTheme.Palette.tileValue,
                shadow: ParchmentTheme.Palette.tileValueShadow.withAlphaComponent(0.82)
            )
            depthNode.fillColor = ParchmentTheme.Palette.tileDepth

        case .freshUnlocked:
            fillColor = ParchmentTheme.Palette.tileFill
            strokeColor = isHintedState
                ? ParchmentTheme.Palette.tileHint
                : ParchmentTheme.Palette.tileStroke
            letterLabel.fontColor = ParchmentTheme.Palette.tileText
            setValueLabelColors(
                main: ParchmentTheme.Palette.tileValue,
                shadow: ParchmentTheme.Palette.tileValueShadow.withAlphaComponent(0.80)
            )
            depthNode.fillColor = ParchmentTheme.Palette.tileDepth
        }

        updateBadgeAppearance()
        updateInfusionAppearance()
    }

    private func setValueLabelColors(main: SKColor, shadow: SKColor) {
        valueLabel.fontColor = main
        valueShadowLabel.fontColor = shadow
    }

    private func updateBadgeAppearance() {
        switch freshness {
        case .normal:
            badgeNode.isHidden = true

        case .freshLocked:
            badgeNode.isHidden = true

        case .freshUnlocked:
            badgeNode.isHidden = true
            badgeLabel.text = nil
        }
    }

    private func updateInfusionAppearance() {
        guard let style = infusionStyle(for: infusion) else {
            hideInfusionAccent()
            return
        }

        infusionAccentNode.isHidden = false
        infusionBadgeNode.isHidden = false

        let selectedAlpha: CGFloat = isHighlightedState ? 0.72 : 0.94
        infusionAccentNode.strokeColor = style.color.withAlphaComponent(selectedAlpha)
        infusionAccentNode.lineWidth = isHighlightedState
            ? max(1.2, ParchmentTheme.Stroke.tileInfusionAccent - 0.2)
            : ParchmentTheme.Stroke.tileInfusionAccent

        infusionBadgeNode.fillColor = style.color.withAlphaComponent(isHighlightedState ? 0.14 : 0.20)
        infusionBadgeNode.strokeColor = style.color.withAlphaComponent(isHighlightedState ? 0.72 : 0.90)
        infusionBadgeLabel.fontColor = ParchmentTheme.Palette.tileInfusionBadgeText.withAlphaComponent(
            isHighlightedState ? 0.88 : 1.0
        )
        infusionBadgeLabel.text = style.badgeText
    }

    private func hideInfusionAccent() {
        infusionAccentNode.isHidden = true
        infusionBadgeNode.isHidden = true
        infusionBadgeLabel.text = nil
    }

    private func infusionStyle(for infusion: TileInfusion) -> (color: SKColor, badgeText: String)? {
        switch infusion {
        case .none:
            return nil
        case .x2:
            return (ParchmentTheme.Palette.tileInfusionX2, "x2")
        case .x3:
            return (ParchmentTheme.Palette.tileInfusionX3, "x3")
        case .bonus:
            return (ParchmentTheme.Palette.tileInfusionBonus, "+")
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
