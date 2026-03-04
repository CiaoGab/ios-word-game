import SwiftUI

/// Style constants and colour tokens for the live word-feedback pill and score-pop overlay.
///
/// Adjust any value here to tune the feel without touching view or controller logic.
/// ─────────────────────────────────────────────────────────────────
///   Timing                 default
///   validPillDuration      0.6 s   – how long "+N" green flash stays
///   invalidShakeDuration   0.32 s  – total shake animation time
///   scorePopDuration       0.65 s  – score pop rise + fade
///
///   Geometry               default
///   invalidShakeAmplitude  10 pt   – peak horizontal offset per shake cycle
///   invalidShakesPerUnit   3       – oscillation count per animation unit
///   scorePopRise           38 pt   – upward travel of the score pop
/// ─────────────────────────────────────────────────────────────────
enum WordFeedbackStyle {

    // MARK: - Tunables

    enum Tunables {
        /// How long the "+N pts" valid flash stays in the pill before reverting to idle.
        static let validPillDuration: TimeInterval = 0.6

        /// Total duration of the invalid-pill shake animation.
        static var invalidShakeDuration: TimeInterval {
            AppSettings.reduceMotion ? 0.18 : 0.32
        }

        /// Peak horizontal displacement (pts) of each shake oscillation.
        static var invalidShakeAmplitude: CGFloat {
            AppSettings.reduceMotion ? 4 : 10
        }

        /// Full oscillations per animation-unit used by ShakeEffect.
        static var invalidShakesPerUnit: CGFloat {
            AppSettings.reduceMotion ? 1.3 : 3
        }

        /// Vertical rise distance (pts) for the floating score pop.
        static var scorePopRise: CGFloat {
            AppSettings.reduceMotion ? 16 : 38
        }

        /// Rise + fade duration for the floating score pop.
        static var scorePopDuration: TimeInterval {
            AppSettings.reduceMotion ? 0.34 : 0.65
        }
    }

    // MARK: - Mini tile geometry

    /// Tweak these values to resize / respace the mini letter tiles in the word pill.
    enum MiniTile {
        /// Side length (pts) of each tile square.
        static let size: CGFloat = 34
        /// Corner radius of the rounded rect background.
        static let cornerRadius: CGFloat = 8
        /// Border stroke width.
        static let strokeWidth: CGFloat = 2.5
        /// Drop-shadow vertical offset.
        static let shadowY: CGFloat = 3
        /// Gap between adjacent tiles.
        static let spacing: CGFloat = 5
    }

    // MARK: - Colours

    enum Colors {
        /// Pill border and label tint for a valid submission.
        static let validBorder: Color = ParchmentTheme.Palette.objectiveGreenText
        static let validText: Color   = ParchmentTheme.Palette.objectiveGreenText

        /// Pill border tint for an invalid submission.
        static let invalidBorder: Color = ParchmentTheme.Palette.footerRed
        /// Label tint for an invalid submission.
        static let invalidText: Color   = ParchmentTheme.Palette.footerRedStroke
    }
}
