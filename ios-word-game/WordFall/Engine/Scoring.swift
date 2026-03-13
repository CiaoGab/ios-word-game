import Foundation

/// Step 28 tuning north star:
/// - supports 4-20 letter submissions with a soft score ceiling for ultra-long words
struct WordScorer {

    enum Tunables {
        /// Scalar applied to letter sums to align scores with the target ranges.
        static let letterSumScale: Double = 4.0
        static let lengthMultipliers: [Int: Double] = [
            4: 1.00,
            5: 1.20,
            6: 1.45,
            7: 1.75,
            8: 2.10,
            9: 2.40,
            10: 2.70,
            11: 2.95,
            12: 3.20,
            13: 3.40,
            14: 3.58,
            15: 3.74,
            16: 3.88,
            17: 4.00,
            18: 4.10,
            19: 4.18,
            20: 4.25
        ]
        static let repeatPenaltyBySubmissionCount: [Int: Double] = [
            1: 1.00, 2: 0.75, 3: 0.55
        ]
        static let repeatPenaltyFloor: Double = 0.40
        static let lockBonusPerLock: Int = 20
    }

    static func lengthMultiplier(for length: Int) -> Double {
        switch length {
        case ..<4:
            return 1.0
        case 20...:
            return Tunables.lengthMultipliers[20] ?? 4.25
        default:
            return Tunables.lengthMultipliers[length] ?? 1.0
        }
    }

    /// Repeat penalty from the 1-indexed submission count for a word in the current run.
    static func repeatMultiplier(forSubmissionCount submissionCount: Int) -> Double {
        let clamped = max(1, submissionCount)
        return Tunables.repeatPenaltyBySubmissionCount[clamped] ?? Tunables.repeatPenaltyFloor
    }

    /// Public helper when you have the number of prior uses (0 = first use).
    static func repeatMultiplier(forPriorUseCount priorUseCount: Int) -> Double {
        repeatMultiplier(forSubmissionCount: max(0, priorUseCount) + 1)
    }

    static func scoreWord(
        letterSum: Int,
        length: Int,
        priorUseCount: Int,
        lockCount: Int
    ) -> Int {
        let lengthAdjusted = Double(letterSum) * Tunables.letterSumScale * lengthMultiplier(for: length)
        let repeated = (lengthAdjusted * repeatMultiplier(forPriorUseCount: priorUseCount)).rounded()
        let baseWordScore = max(Int(repeated), 1)
        return baseWordScore + (max(0, lockCount) * Tunables.lockBonusPerLock)
    }

    func scoreWord(
        letters: String,
        lockCount: Int,
        wordUseCounts: [String: Int]
    ) -> Int {
        let wordKey = letters.uppercased()
        let priorUseCount = wordUseCounts[wordKey, default: 0]
        let letterSum = LetterValues.sum(for: wordKey)
        return Self.scoreWord(
            letterSum: letterSum,
            length: wordKey.count,
            priorUseCount: priorUseCount,
            lockCount: lockCount
        )
    }
}

enum Scoring {

    // MARK: - Core helpers

    static func lengthMultiplier(for length: Int) -> Double {
        WordScorer.lengthMultiplier(for: length)
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
