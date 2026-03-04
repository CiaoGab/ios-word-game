import Foundation

enum Scoring {

    // MARK: - Tunables

    enum Tunables {
        /// Length multipliers applied to the letter-value sum.
        /// Edit here to rebalance word-length rewards.
        static let lengthMultipliers: [Int: Double] = [3: 1.0, 4: 1.25, 5: 1.6, 6: 2.0]

        /// Repeat-penalty curve indexed by prior use count (0 = first use → 100%).
        /// Uses beyond index 4 are capped at the last entry.
        static let repeatCurve: [Double] = [1.0, 0.7, 0.5, 0.35, 0.25]

        /// Absolute floor for any word score, regardless of penalty.
        static let minPointsBase: Int = 5

        /// Per-letter floor contribution (adds length * this to minPoints).
        static let minPointsPerLetter: Int = 2
    }

    // MARK: - Core helpers

    /// Length multiplier from the tunable table (defaults to 1.0 for unknown lengths).
    static func lengthMultiplier(for length: Int) -> Double {
        Tunables.lengthMultipliers[length] ?? 1.0
    }

    /// Repeat-penalty multiplier. useCount = number of prior submissions (0 = first use).
    static func repeatMultiplier(useCount: Int) -> Double {
        let curve = Tunables.repeatCurve
        return curve[min(useCount, curve.count - 1)]
    }

    /// Minimum points guaranteed for a word of the given length.
    /// floor = max(minPointsBase, length * minPointsPerLetter)
    static func minPoints(length: Int) -> Int {
        max(Tunables.minPointsBase, length * Tunables.minPointsPerLetter)
    }

    // MARK: - Primary scoring entry point

    /// Final word score with repeat penalty and floor applied.
    ///   base     = sum of letter values
    ///   raw      = round(base × lenMult × repeatMult)
    ///   final    = max(minPoints(length), raw)
    ///
    /// This is the value that should be added to both state.score and
    /// run.scoreThisBoard on every accepted word.
    static func wordScore(letterSum: Int, length: Int, useCount: Int) -> Int {
        let raw = (Double(letterSum) * lengthMultiplier(for: length) * repeatMultiplier(useCount: useCount)).rounded()
        return max(minPoints(length: length), Int(raw))
    }

    // MARK: - Legacy helpers (used by Resolver for event display; not used for score tracking)

    /// Base word points without repeat penalty.
    /// Still used by the Resolver to populate ClearEvent.awardedPoints for animations.
    static func baseWordPoints(letterSum: Int, length: Int) -> Int {
        let multiplied = Double(letterSum) * lengthMultiplier(for: length)
        return Int(multiplied.rounded()) + lengthBonus(for: length)
    }

    static func cascadePoints(letterSum: Int, length: Int, cascadeStep: Int) -> Int {
        let base = baseWordPoints(letterSum: letterSum, length: length)
        let multiplier = cascadeMultiplier(for: cascadeStep)
        return Int((Double(base) * multiplier).rounded())
    }

    static func inkPoints(letterSum: Int, length: Int, isCascade: Bool) -> Int {
        let base: Int
        switch length {
        case 5:
            base = letterSum + 2
        case 6:
            base = letterSum + 5
        default:
            base = letterSum
        }
        return isCascade ? (base / 2) : base
    }

    static func lengthBonus(for length: Int) -> Int {
        switch length {
        case 5: return 40
        case 6: return 90
        default: return 0
        }
    }

    static func cascadeMultiplier(for step: Int) -> Double {
        switch step {
        case 1: return 1.0
        case 2: return 1.5
        case 3: return 2.0
        default:
            return min(4.0, 2.0 + (0.5 * Double(step - 3)))
        }
    }
}
