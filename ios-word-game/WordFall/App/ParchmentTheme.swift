import SwiftUI
import UIKit

enum ParchmentTheme {
    enum Palette {
        static let paperBase = Color(hex: 0xFDF6E3)
        static let paperDust = Color(hex: 0xE6DBB9)
        static let paperDoodle = Color(hex: 0xC8B68A)
        static var ink: Color {
            AppSettings.highContrast ? Color(hex: 0x141414) : Color(hex: 0x2A2A2A)
        }
        static var slate: Color {
            AppSettings.highContrast ? Color(hex: 0x334155) : Color(hex: 0x64748B)
        }
        static let white = Color.white
        static let levelYellow = Color(hex: 0xFEF9C3)

        static let boardOuter = Color.white.opacity(0.34)
        static let boardDash = Color(hex: 0x94A3B8, alpha: 0.58)
        static let boardInset = Color.white.opacity(0.48)
        static let boardInner = Color(hex: 0xF5F5F2)
        static let boardDashSK = UIColor(hex: 0xA3B1C2, alpha: 0.62)
        static let boardStrokeSK = UIColor(hex: 0x5B4636, alpha: 0.42)
        static let boardInnerStrokeSK = UIColor(hex: 0x6B7280, alpha: 0.24)

        static let tileFill = UIColor(hex: 0xFFFFFF)
        static var tileStroke: UIColor {
            AppSettings.highContrast ? UIColor(hex: 0x111111) : UIColor(hex: 0x2A2A2A)
        }
        static var tileText: UIColor {
            AppSettings.highContrast ? UIColor(hex: 0x111111) : UIColor(hex: 0x2A2A2A)
        }
        static var tileValue: UIColor {
            AppSettings.highContrast
                ? UIColor(hex: 0x0F172A, alpha: 0.96)
                : UIColor(hex: 0x1F2937, alpha: 0.82)
        }
        static let tileValueShadow = UIColor(hex: 0xFFFFFF, alpha: 0.82)
        static let tileDepth = UIColor(hex: 0xE0E0E0)
        static let tileSelectedFill = UIColor(hex: 0xE3FAFC)
        static var tileSelectedStroke: UIColor {
            AppSettings.highContrast ? UIColor(hex: 0x0E7490) : UIColor(hex: 0x1098AD)
        }
        static var tileSelectedText: UIColor {
            AppSettings.highContrast ? UIColor(hex: 0x0B5566) : UIColor(hex: 0x0B7285)
        }
        static let tileMatchFill = UIColor(hex: 0xFFE066)
        static let tileMatchStroke = UIColor(hex: 0xE67700)
        static let tileMatchText = UIColor(hex: 0xE67700)
        static let tileHint = UIColor(hex: 0x22D3EE)
        static let tileLockedBadgeFill = UIColor(hex: 0xE3F2FF)
        static let tileLockedBadgeStroke = UIColor(hex: 0x1D8ED8)
        static let tileLockedBadgeText = UIColor(hex: 0x0B5A8E)
        static let tileUnlockedBadgeFill = UIColor(hex: 0xF1F3F5)
        static let tileUnlockedBadgeStroke = UIColor(hex: 0x868E96)
        static let tileUnlockedBadgeText = UIColor(hex: 0x495057)
        static let tileInfusionX2 = UIColor(hex: 0x2F9E44)
        static let tileInfusionX3 = UIColor(hex: 0x7C3AED)
        static let tileInfusionBonus = UIColor(hex: 0xB9770E)
        static let tileInfusionBadgeText = UIColor(hex: 0x5A3A08)

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
        static var hud: CGFloat {
            AppSettings.highContrast ? 3.7 : 3.0
        }
        static var boardDashed: CGFloat {
            AppSettings.highContrast ? 2.4 : 2.0
        }
        static var boardContainer: CGFloat {
            AppSettings.highContrast ? 2.5 : 2.0
        }
        static var button: CGFloat {
            AppSettings.highContrast ? 4.8 : 4.0
        }
        static var tile: CGFloat {
            AppSettings.highContrast ? 3.8 : 3.0
        }
        static var badge: CGFloat {
            AppSettings.highContrast ? 2.2 : 1.8
        }
        static var tileInfusionAccent: CGFloat {
            AppSettings.highContrast ? 2.1 : 1.7
        }
    }

    enum Radius {
        static let hudPill: CGFloat = 999
        static let boardOuter: CGFloat = 24
        static let boardInner: CGFloat = 20
        static let tile: CGFloat = 12
        static let button: CGFloat = 48
        static let smallPill: CGFloat = 999
    }

    enum Shadow {
        static let hud = (x: CGFloat(4), y: CGFloat(4), radius: CGFloat(0), opacity: Double(0.10))
        static let board = (x: CGFloat(0), y: CGFloat(8), radius: CGFloat(9), opacity: Double(0.10))
        static let button = (x: CGFloat(0), y: CGFloat(5), radius: CGFloat(0), opacity: Double(0.20))
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }
}

extension Font {
    static func parchmentRounded(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

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
