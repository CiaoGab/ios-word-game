import Foundation

struct LetterBag {
    private let weightedLetters: [Character]

    init(weights: [(Character, Int)] = Self.defaultWeights) {
        self.weightedLetters = weights.flatMap { letter, weight in
            Array(repeating: letter, count: max(1, weight))
        }
    }

    mutating func nextLetter() -> Character {
        weightedLetters.randomElement() ?? "E"
    }

    mutating func nextTile() -> Tile {
        Tile(id: UUID(), letter: nextLetter())
    }

    /// Draws a letter while respecting per-board caps for rare letters and the hard vowel cap.
    /// If the drawn letter is already at its cap (rare or vowel), retries up to `retryLimit` times.
    /// Falls back to a common consonant when vowel-capped, or a vowel otherwise.
    mutating func nextLetter(
        respecting caps: [Character: Int],
        existingCounts: inout [Character: Int],
        retryLimit: Int = 4
    ) -> Character {
        let vowelCount = Self.vowelSet.reduce(0) { $0 + (existingCounts[$1, default: 0]) }
        let vowelCapped = vowelCount >= Self.maxVowels

        for _ in 0..<retryLimit {
            let candidate = nextLetter()
            // Reject vowels when the board vowel cap is reached.
            if vowelCapped && Self.vowelSet.contains(candidate) { continue }
            let limit = caps[candidate] ?? Int.max
            if existingCounts[candidate, default: 0] < limit {
                existingCounts[candidate, default: 0] += 1
                return candidate
            }
        }
        // All retries hit caps — fall back to consonant when vowel-capped, else a vowel.
        let fallback: Character
        if vowelCapped {
            fallback = Self.consonantFallbacks.randomElement() ?? "T"
        } else {
            fallback = Self.vowelFallbacks.randomElement() ?? "E"
        }
        existingCounts[fallback, default: 0] += 1
        return fallback
    }

    mutating func nextTile(
        respecting caps: [Character: Int],
        existingCounts: inout [Character: Int]
    ) -> Tile {
        Tile(id: UUID(), letter: nextLetter(respecting: caps, existingCounts: &existingCounts))
    }

    // MARK: – Constants

    /// Max occurrences of each rare letter allowed per 7×7 board.
    /// Applied during initial generation AND during spawns.
    static let rareCaps: [Character: Int] = [
        "Q": 1, "X": 1, "Z": 1, "J": 1, "K": 1
    ]

    /// Hard vowel cap per 7×7 board (49 tiles).
    /// When vowelCount reaches this limit, new draws reroll from consonants only.
    static let maxVowels: Int = 20

    /// Set of vowel characters used for vowel-cap tracking.
    static let vowelSet: Set<Character> = ["A", "E", "I", "O", "U"]

    private static let vowelFallbacks: [Character] = ["A", "E", "I", "O", "U"]
    private static let consonantFallbacks: [Character] = ["T", "N", "R", "S", "L"]

    /// Weighted letter distribution.
    /// Vowel target: ~40 % of bag weight (46/115); hard cap via maxVowels.
    /// Common consonants (T,N,R,S,L) slightly boosted.
    /// Mid-rares (V,W,Y) reduced; rare letters (Q,X,Z,J,K) capped per-board via rareCaps.
    static let defaultWeights: [(Character, Int)] = [
        // Vowels — ~40 % of total weight (46/115)
        ("A", 11), ("E", 11), ("I", 9), ("O", 9), ("U", 6),
        // Common consonants — slightly boosted
        ("T", 10), ("N", 8), ("R", 8), ("S", 7), ("L", 6),
        // Medium-frequency consonants
        ("D", 4), ("G", 3), ("C", 3), ("M", 3), ("P", 3),
        // Lower-frequency consonants — B/F/H unchanged; V/W/Y reduced
        ("B", 2), ("F", 2), ("H", 2), ("V", 1), ("W", 1), ("Y", 1),
        // Rare letters — weight kept at 1; caps enforced separately
        ("K", 1), ("J", 1), ("X", 1), ("Q", 1), ("Z", 1)
    ]
}
