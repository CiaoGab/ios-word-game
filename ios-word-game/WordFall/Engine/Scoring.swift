import Foundation

enum Scoring {
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

    static func lengthMultiplier(for length: Int) -> Double {
        switch length {
        case 3: return 1.0
        case 4: return 1.25
        case 5: return 1.6
        case 6: return 2.0
        default: return 1.0
        }
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
