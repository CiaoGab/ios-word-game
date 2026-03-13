import SwiftUI
import UIKit

// MARK: - ParchmentTheme (compatibility layer → Stitch tokens)
// New code should use StitchTheme directly.

enum ParchmentTheme {
    enum Roguelike {
        enum Palette {
            static var goldAccent: Color { StitchTheme.Colors.accentGold }
            static var cardBackground: Color { StitchTheme.Colors.bgSheet }
            static var tileBackground: Color { StitchTheme.Colors.surfaceCardAlt }
            static var tileStroke: Color { StitchTheme.Colors.strokeSoft }
            static var textPrimary: Color { StitchTheme.Colors.inkPrimary }
            static var textSecondary: Color { StitchTheme.Colors.inkSecondary }
            static var darkButton: Color { StitchTheme.Colors.inkPrimary }
            static var darkButtonText: Color { Color(hex: 0xF3F4F6) }
            static var backdrop: Color { StitchTheme.Colors.backdrop }
        }

        enum Radius {
            static let modalCard: CGFloat = 32
            static let tile: CGFloat = 20
            static let rowCard: CGFloat = 22
            static let button: CGFloat = 22
        }

        enum Shadow {
            static let modal = (color: StitchTheme.Colors.shadowColor.opacity(0.16), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(14))
            static let tile = (color: StitchTheme.Colors.shadowColor.opacity(0.08), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        }
    }

    enum Palette {
        static var paperBase: Color { StitchTheme.Colors.bgCanvas }
        static let paperDust = Color(hex: 0xE6DBB9)
        static let paperDoodle = Color(hex: 0xC8B68A)
        static var ink: Color { StitchTheme.Colors.inkPrimary }
        static var slate: Color { StitchTheme.Colors.inkSecondary }
        static let white = Color.white
        static let levelYellow = Color(hex: 0xFEF9C3)

        static var boardOuter: Color { StitchTheme.Board.containerFill.opacity(0.85) }
        static var boardDash: Color { StitchTheme.Board.dashRingColor }
        static var boardInset: Color { StitchTheme.Colors.surfaceCard.opacity(0.48) }
        static var boardInner: Color { StitchTheme.Colors.surfaceCardAlt }
        static var boardDashSK: UIColor { StitchTheme.Board.dashRingColorSK }
        static var boardStrokeSK: UIColor { StitchTheme.ColorsSK.strokeSoft }
        static var boardInnerStrokeSK: UIColor { StitchTheme.ColorsSK.strokeSoft }

        static var tileFill: UIColor { StitchTheme.Tile.fill }
        static var tileStroke: UIColor { StitchTheme.Tile.stroke }
        static var tileText: UIColor { StitchTheme.ColorsSK.inkPrimary }
        static var tileValue: UIColor { StitchTheme.Tile.valueText }
        static var tileValueShadow: UIColor { StitchTheme.Tile.valueShadow }
        static var tileDepth: UIColor { StitchTheme.Tile.depthShadow }
        static var tileSelectedFill: UIColor { StitchTheme.Tile.selectedFill }
        static var tileSelectedStroke: UIColor { StitchTheme.Tile.selectedStroke }
        static var tileSelectedText: UIColor { StitchTheme.Tile.selectedText }
        static var tileMatchFill: UIColor { StitchTheme.Tile.matchFill }
        static var tileMatchStroke: UIColor { StitchTheme.Tile.matchStroke }
        static var tileMatchText: UIColor { StitchTheme.Tile.matchText }
        static var tileHint: UIColor { StitchTheme.Tile.hintStroke }
        static var tileLockedBadgeFill: UIColor { StitchTheme.Tile.lockedBadgeFill }
        static var tileLockedBadgeStroke: UIColor { StitchTheme.Tile.lockedBadgeStroke }
        static var tileLockedBadgeText: UIColor { StitchTheme.Tile.lockedBadgeText }
        static let tileUnlockedBadgeFill = UIColor(hex: 0xF1F3F5)
        static let tileUnlockedBadgeStroke = UIColor(hex: 0x868E96)
        static let tileUnlockedBadgeText = UIColor(hex: 0x495057)
        static var tileInfusionX2: UIColor { StitchTheme.Tile.infusionX2 }
        static var tileInfusionX3: UIColor { StitchTheme.Tile.infusionX3 }
        static var tileInfusionBonus: UIColor { StitchTheme.Tile.infusionBonus }
        static var tileInfusionBadgeText: UIColor { StitchTheme.Tile.infusionBadgeText }

        static let footerBlue = Color(hex: 0x4DABF7)
        static let footerBlueStroke = Color(hex: 0x2563EB)
        static let footerYellow = Color(hex: 0xFCC419)
        static let footerYellowStroke = Color(hex: 0xEAB308)
        static let footerRed = Color(hex: 0xFF6B6B)
        static let footerRedStroke = Color(hex: 0xEF4444)
        static let footerPurple = Color(hex: 0xCC5DE8)
        static let footerPurpleStroke = Color(hex: 0xA855F7)

        static let objectiveGreen = Color(hex: 0x51CF66)
        static var objectiveGreenText: Color {
            AppSettings.highContrast ? Color(hex: 0x1E7A33) : Color(hex: 0x2F9E44)
        }
        static let objectiveTagFill = Color(hex: 0xDCFCE7)
        static let objectiveTagStroke = Color(hex: 0xBBF7D0)
    }

    enum Stroke {
        static var hud: CGFloat { StitchTheme.Stroke.bold }
        static var boardDashed: CGFloat { StitchTheme.Board.dashRingWidth }
        static var boardContainer: CGFloat { StitchTheme.Board.containerStrokeWidth }
        static var button: CGFloat { StitchTheme.Stroke.bold }
        static var tile: CGFloat { StitchTheme.Tile.strokeWidth }
        static var badge: CGFloat { StitchTheme.Stroke.standard }
        static var tileInfusionAccent: CGFloat { StitchTheme.Stroke.standard }
    }

    enum Radius {
        static let hudPill: CGFloat = StitchTheme.Radii.pill
        static var boardOuter: CGFloat { StitchTheme.Board.cornerRadius }
        static var boardInner: CGFloat { StitchTheme.Board.innerCornerRadius }
        static let tile: CGFloat = 24
        static let button: CGFloat = 48
        static let smallPill: CGFloat = StitchTheme.Radii.pill
    }

    enum Shadow {
        static let hud = (x: CGFloat(4), y: CGFloat(4), radius: CGFloat(0), opacity: Double(0.10))
        static var board: (x: CGFloat, y: CGFloat, radius: CGFloat, opacity: Double) {
            (0, 8, 9, 0.10)
        }
        static let button = (x: CGFloat(0), y: CGFloat(5), radius: CGFloat(0), opacity: Double(0.20))
    }

    enum Spacing {
        static let xs: CGFloat = StitchTheme.Space._1
        static let sm: CGFloat = StitchTheme.Space._2
        static let md: CGFloat = StitchTheme.Space._3
        static let lg: CGFloat = StitchTheme.Space._4
        static let xl: CGFloat = StitchTheme.Space._5
        static let xxl: CGFloat = StitchTheme.Space._6
    }
}

extension Font {
    static func parchmentRounded(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.stitchRounded(size: size, weight: weight)
    }
}
