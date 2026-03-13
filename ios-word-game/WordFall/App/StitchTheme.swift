import SwiftUI
import UIKit

// MARK: - Stitch premium roguelike design system
//
// Single source of truth for WordFall: warm ivory canvas, white cards, charcoal ink, gold accent.
// High Contrast → stroke.strong, darker ink. Reduce Motion → fewer glows/pulses, same static styling.

enum StitchTheme {
    // MARK: - Colors

    enum Colors {
        static var bgCanvas: Color { Color(hex: 0xFDF6E3) }
        static var bgSheet: Color { Color(hex: 0xF7F7F5) }
        static var surfaceCard: Color { .white }
        static var surfaceCardAlt: Color { Color(hex: 0xF5F5F2) }

        static var inkPrimary: Color {
            AppSettings.highContrast ? Color(hex: 0x141414) : Color(hex: 0x1F2329)
        }
        static var inkSecondary: Color {
            AppSettings.highContrast ? Color(hex: 0x334155) : Color(hex: 0x6B7280)
        }
        static var inkMuted: Color {
            AppSettings.highContrast ? Color(hex: 0x475569) : Color(hex: 0x9CA3AF)
        }

        static var accentGold: Color { Color(hex: 0xC79A3B) }
        static var accentGoldSoft: Color { Color(hex: 0xE8D5A3) }
        static var accentGoldStroke: Color { Color(hex: 0xA67C2E) }
        static var destructiveFill: Color { Color(hex: 0xF6E4DE) }
        static var destructiveFillPressed: Color { Color(hex: 0xF2D8CF) }
        static var destructiveStroke: Color { Color(hex: 0xD08C7A) }
        static var destructiveText: Color {
            AppSettings.highContrast ? Color(hex: 0x7A211D) : Color(hex: 0x9F3F38)
        }

        static var strokeSoft: Color { Color(hex: 0x1F2329).opacity(0.18) }
        static var strokeStrong: Color { Color(hex: 0x1F2329) }
        static var strokeStandard: Color {
            AppSettings.highContrast ? strokeStrong : Color(hex: 0x1F2329).opacity(0.35)
        }

        static var shadowColor: Color { Color(hex: 0x1F2329) }

        /// Modal/sheet backdrop
        static var backdrop: Color { Color.black.opacity(0.45) }
    }

    // MARK: - Radii

    enum Radii {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Strokes (line widths)

    enum Stroke {
        static var hairline: CGFloat { 1.0 }
        static var standard: CGFloat { AppSettings.highContrast ? 2.2 : 1.8 }
        static var bold: CGFloat { AppSettings.highContrast ? 3.2 : 2.6 }
    }

    // MARK: - Shadows

    enum Shadow {
        static var card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Colors.shadowColor.opacity(0.10), 8, 0, 4)
        }
        static var sheet: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Colors.shadowColor.opacity(0.14), 14, 0, 8)
        }
        static var insetSoft: (color: Color, radius: CGFloat) {
            (Colors.shadowColor.opacity(0.06), 4)
        }
    }

    // MARK: - Spacing

    enum Space {
        static let _1: CGFloat = 4
        static let _2: CGFloat = 8
        static let _3: CGFloat = 12
        static let _4: CGFloat = 16
        static let _5: CGFloat = 20
        static let _6: CGFloat = 24
    }

    // MARK: - Typography

    enum Typography {
        static func title(size: CGFloat = 28, weight: Font.Weight = .heavy) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func subtitle(size: CGFloat = 18, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func labelCaps(size: CGFloat = 11, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func valueHero(size: CGFloat = 34, weight: Font.Weight = .black) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func body(size: CGFloat = 16, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func caption(size: CGFloat = 12, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }
    }
}

// MARK: - UIKit / SpriteKit tokens (UIColor)

extension StitchTheme {
    enum ColorsSK {
        static var inkPrimary: UIColor {
            AppSettings.highContrast ? UIColor(hex: 0x141414) : UIColor(hex: 0x1F2329)
        }
        static var accentGold: UIColor { UIColor(hex: 0xC79A3B) }
        static var accentGoldSoft: UIColor { UIColor(hex: 0xE8D5A3) }
        static var surfaceCard: UIColor { .white }
        static var strokeSoft: UIColor { UIColor(hex: 0x1F2329, alpha: 0.22) }
        static var strokeStrong: UIColor { UIColor(hex: 0x111111) }
        static var strokeStandard: UIColor {
            AppSettings.highContrast ? strokeStrong : UIColor(hex: 0x2A2A2A)
        }
        static var shadowColor: UIColor { UIColor(hex: 0x1F2329, alpha: 0.12) }
    }
}

// MARK: - Hex color helpers (shared)

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Font shorthand (parchment-style rounded)

extension Font {
    static func stitchRounded(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Board & tile tokens (SpriteKit / SwiftUI)

extension StitchTheme {
    enum BoardGame {
        static let canvas = Color(hex: 0xF8F7F6)
        static let canvasWarm = Color(hex: 0xF5F2ED)
        static let surface = Color(hex: 0xFFFEFB)
        static let surfaceWarm = Color(hex: 0xF1ECDD)
        static let surfaceMuted = Color(hex: 0xE2E8F0)
        static let surfaceMutedBorder = Color(hex: 0xCBD5E1)
        static let outline = Color(hex: 0x2D2A1E)
        static let gold = Color(hex: 0xDEB42B)
        static let goldStrong = Color(hex: 0xB8921F)
        static let goldWash = Color(hex: 0xDEB42B, alpha: 0.10)
        static let textPrimary = Color(hex: 0x2D2A1E)
        static let textSecondary = Color(hex: 0x64748B)
        static let textMuted = Color(hex: 0x94A3B8)

        enum Depth {
            static let soft: CGFloat = 3
            static let card: CGFloat = 4
            static let lifted: CGFloat = 6
        }
    }

    enum RuunChrome {
        static let screenHorizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24

        static let headerControlSize: CGFloat = 40
        static let headerControlRadius: CGFloat = 16
        static let headerControlLineWidth: CGFloat = 2.4
        static let headerControlDepth: CGFloat = 2
        static let headerBottomPadding: CGFloat = 14

        static let panelRadius: CGFloat = 28
        static let panelLineWidth: CGFloat = 2.8
        static let panelDepth: CGFloat = 6

        static let cardRadius: CGFloat = 24
        static let cardLineWidth: CGFloat = 2.4
        static let cardDepth: CGFloat = 4
        static let secondaryCardRadius: CGFloat = 16
        static let secondaryCardLineWidth: CGFloat = 2

        static let iconChipSize: CGFloat = 40
        static let iconChipRadius: CGFloat = 14
        static let iconChipLineWidth: CGFloat = 2.2

        static let buttonHeight: CGFloat = 56
        static let buttonRadius: CGFloat = 24
        static let buttonLineWidth: CGFloat = 2.4
        static let buttonDepth: CGFloat = 4

        static let sectionHeadingIconSize: CGFloat = 13
        static let sectionHeadingSpacing: CGFloat = 8
        static let sectionHeadingTracking: CGFloat = 0.9
    }

    enum Board {
        static var containerFill: Color { BoardGame.surfaceWarm }
        static var containerStroke: Color { BoardGame.outline }
        static var containerStrokeWidth: CGFloat { AppSettings.highContrast ? 3.4 : 3.0 }
        static var dashRingColor: Color { BoardGame.gold.opacity(0.42) }
        static var dashRingColorSK: UIColor { UIColor(hex: 0xDEB42B, alpha: 0.42) }
        static var dashRingWidth: CGFloat { AppSettings.highContrast ? 2.2 : 1.6 }
        static var cornerRadius: CGFloat { 28 }
        static var innerCornerRadius: CGFloat { 24 }
    }

    enum Tile {
        static var fill: UIColor { UIColor(hex: 0xFFFEFB) }
        static var stroke: UIColor { UIColor(hex: 0x2D2A1E) }
        static var strokeWidth: CGFloat { AppSettings.highContrast ? 3.4 : 2.8 }
        static var valueText: UIColor { UIColor(hex: 0x2D2A1E, alpha: 0.74) }
        static var valueShadow: UIColor { UIColor(hex: 0xFFFEFB, alpha: 0.88) }
        static var depthShadow: UIColor { UIColor(hex: 0x2D2A1E) }
        static var selectedStroke: UIColor { UIColor(hex: 0x2D2A1E) }
        static var selectedFill: UIColor { UIColor(hex: 0xDEB42B) }
        static var selectedText: UIColor { UIColor(hex: 0xFFFBEF) }
        static var lockedBadgeFill: UIColor { UIColor(hex: 0xDEB42B) }
        static var lockedBadgeStroke: UIColor { UIColor(hex: 0x2D2A1E) }
        static var lockedBadgeText: UIColor { UIColor(hex: 0x2D2A1E) }
        static var hintStroke: UIColor { UIColor(hex: 0x94A3B8) }
        static var matchFill: UIColor { UIColor(hex: 0xDEB42B) }
        static var matchStroke: UIColor { UIColor(hex: 0x2D2A1E) }
        static var matchText: UIColor { UIColor(hex: 0xFFFBEF) }
        /// Infusion accent colors (max 3 for corner badges)
        static var infusionX2: UIColor { UIColor(hex: 0x2F9E44) }
        static var infusionX3: UIColor { UIColor(hex: 0x7C3AED) }
        static var infusionBonus: UIColor { UIColor(hex: 0xB9770E) }
        static var infusionBadgeText: UIColor { UIColor(hex: 0x5A3A08) }
    }
}

// MARK: - Button styles (Primary = gold, Secondary = charcoal, Tertiary = ghost)

struct StitchPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.stitchRounded(size: 18, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                    .fill(StitchTheme.Colors.accentGold)
                    .overlay(
                        RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                            .stroke(StitchTheme.Colors.accentGoldStroke, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
            .shadow(
                color: StitchTheme.Colors.shadowColor.opacity(0.18),
                radius: 6, x: 0, y: 3
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed && !AppSettings.reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StitchSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let sh = StitchTheme.Shadow.card
        configuration.label
            .font(.stitchRounded(size: 18, weight: .heavy))
            .foregroundStyle(StitchTheme.Colors.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                    .fill(StitchTheme.Colors.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                            .stroke(StitchTheme.Colors.strokeStandard, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
            .shadow(color: sh.color, radius: sh.radius, x: sh.x, y: sh.y)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed && !AppSettings.reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StitchDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let sh = StitchTheme.Shadow.card
        let fill = configuration.isPressed
            ? StitchTheme.Colors.destructiveFillPressed
            : StitchTheme.Colors.destructiveFill

        configuration.label
            .font(.stitchRounded(size: 18, weight: .heavy))
            .foregroundStyle(StitchTheme.Colors.destructiveText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: StitchTheme.Radii.lg, style: .continuous)
                            .stroke(StitchTheme.Colors.destructiveStroke, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
            .shadow(color: sh.color, radius: sh.radius, x: sh.x, y: sh.y)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed && !AppSettings.reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StitchTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.stitchRounded(size: 17, weight: .heavy))
            .foregroundStyle(StitchTheme.Colors.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                    .fill(StitchTheme.Colors.surfaceCardAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: StitchTheme.Radii.md, style: .continuous)
                            .stroke(StitchTheme.Colors.strokeSoft, lineWidth: StitchTheme.Stroke.standard)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !AppSettings.reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct StitchRoundedSurface: View {
    let fill: Color
    let border: Color
    let shadow: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let depth: CGFloat
    var dash: [CGFloat] = []

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(shadow)
                .offset(y: depth)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    border,
                    style: StrokeStyle(lineWidth: lineWidth, dash: dash)
                )
        }
    }
}

struct RuunHeaderControl: View {
    let systemImage: String
    var iconSize: CGFloat = 17
    var fill: Color = StitchTheme.BoardGame.surface
    var border: Color = StitchTheme.BoardGame.outline
    var shadow: Color = StitchTheme.BoardGame.outline
    var tint: Color = StitchTheme.BoardGame.textPrimary

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .black))
            .foregroundStyle(tint)
            .frame(
                width: StitchTheme.RuunChrome.headerControlSize,
                height: StitchTheme.RuunChrome.headerControlSize
            )
            .background(
                StitchRoundedSurface(
                    fill: fill,
                    border: border,
                    shadow: shadow,
                    cornerRadius: StitchTheme.RuunChrome.headerControlRadius,
                    lineWidth: StitchTheme.RuunChrome.headerControlLineWidth,
                    depth: StitchTheme.RuunChrome.headerControlDepth
                )
            )
    }
}

struct RuunSectionHeading: View {
    let title: String
    let symbol: String
    var iconColor: Color = StitchTheme.BoardGame.goldStrong
    var textColor: Color = StitchTheme.BoardGame.textPrimary

    var body: some View {
        HStack(spacing: StitchTheme.RuunChrome.sectionHeadingSpacing) {
            Image(systemName: symbol)
                .font(.system(size: StitchTheme.RuunChrome.sectionHeadingIconSize, weight: .black))
                .foregroundStyle(iconColor)

            Text(title.uppercased())
                .font(StitchTheme.Typography.labelCaps(size: 14, weight: .heavy))
                .tracking(StitchTheme.RuunChrome.sectionHeadingTracking)
                .foregroundStyle(textColor)

            Spacer(minLength: 0)
        }
    }
}

struct StitchDotPattern: View {
    let color: Color
    var spacing: CGFloat = 11
    var dotSize: CGFloat = 2.2

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for x in stride(from: dotSize, through: size.width, by: spacing) {
                    for y in stride(from: dotSize, through: size.height, by: spacing) {
                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}
