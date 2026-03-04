import Foundation

struct LetterBag {
    /// Weighted letter pool that excludes extreme-rare and rare letters.
    /// Extreme-rares (Q, Z) and rares (J, X, K) are injected via the rarity gate in drawRaw().
    private let normalWeightedLetters: [Character]

    /// Letters blocked from spawning (used by the rareRelief perk).
    /// Defaults to empty. Set to `["Q","Z","X","J","K"]` when rareRelief is active.
    var excludedLetters: Set<Character> = []

    init(weights: [(Character, Int)] = Self.defaultWeights) {
        self.normalWeightedLetters = weights
            .filter { !Self.rareSet.contains($0.0) }
            .flatMap { letter, weight in
                Array(repeating: letter, count: max(1, weight))
            }
    }

    mutating func nextLetter() -> Character {
        drawRaw()
    }

    mutating func nextTile() -> Tile {
        Tile(id: UUID(), letter: nextLetter())
    }

    /// Draws a letter while respecting per-board caps for rare letters and the hard vowel cap.
    /// Uses the rarity gate so extreme-rares and rares only appear at their configured probabilities.
    /// Falls back to a common consonant when vowel-capped, or a vowel otherwise.
    mutating func nextLetter(
        respecting caps: [Character: Int],
        existingCounts: inout [Character: Int],
        retryLimit: Int = 4
    ) -> Character {
        let vowelCount = Self.vowelSet.reduce(0) { $0 + (existingCounts[$1, default: 0]) }
        let vowelCapped = vowelCount >= Self.maxVowels

        for _ in 0..<retryLimit {
            let candidate = drawRaw()
            // Reject excluded letters (e.g. rareRelief perk blocks Q/Z/X/J/K).
            if excludedLetters.contains(candidate) { continue }
            // Reject vowels when the board vowel cap is reached.
            if vowelCapped && Self.vowelSet.contains(candidate) { continue }
            let limit = caps[candidate] ?? Int.max
            if existingCounts[candidate, default: 0] < limit {
                existingCounts[candidate, default: 0] += 1
                #if DEBUG
                Self.debugRecordDraw(candidate)
                #endif
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

    // MARK: – Private

    /// Draws a raw letter via the three-tier rarity gate.
    ///
    /// - `pExtreme` chance  → extreme-rare pool (Q, Z)
    /// - `pRareNet` chance  → rare pool (J, X, K)
    /// - remaining          → normal weighted pool
    ///
    /// Falls through to a cheaper pool when the selected pool is empty (shouldn't
    /// happen in normal play, but guards against bad custom weight configs).
    private func drawRaw() -> Character {
        let r = Double.random(in: 0..<1)
        if r < Self.pExtreme {
            return Self.extremeRares.randomElement()
                ?? normalWeightedLetters.randomElement() ?? "E"
        } else if r < Self.cutoffRare {
            return Self.rares.randomElement()
                ?? normalWeightedLetters.randomElement() ?? "E"
        }
        return normalWeightedLetters.randomElement() ?? "E"
    }

    // MARK: – Debug

    #if DEBUG
    private static var _debugDrawCount: Int = 0
    private static var _debugRareCount: Int = 0
    private static var _debugBoardHasExtreme: Bool = false
    private static var _debugBoardHasRare: Bool = false
    private static let _debugBoardSize: Int = 49   // 7×7 proxy

    private static func debugRecordDraw(_ letter: Character) {
        _debugDrawCount += 1
        if extremeRares.contains(letter) {
            _debugBoardHasExtreme = true
        }
        if rares.contains(letter) {
            _debugBoardHasRare = true
        }
        if rareSet.contains(letter) {
            _debugRareCount += 1
            print("[LetterBag] Rare spawn: \(letter) (draw #\(_debugDrawCount))")
        }
        if _debugDrawCount % _debugBoardSize == 0 {
            let board = _debugDrawCount / _debugBoardSize
            print("[LetterBag] Board \(board): extremesPresent (Q/Z)=\(_debugBoardHasExtreme), raresPresent (J/X/K)=\(_debugBoardHasRare)")
            let rate = Double(_debugRareCount) / Double(_debugDrawCount) * 100
            print(String(
                format: "[LetterBag] ~Board %d: rare rate %.1f%% (%d/%d draws)",
                board, rate, _debugRareCount, _debugDrawCount
            ))
            _debugBoardHasExtreme = false
            _debugBoardHasRare = false
        }
    }
    #endif

    // MARK: – Constants

    /// Max occurrences of each rare letter allowed per 7×7 board.
    /// Applied during initial generation AND during spawns.
    static let rareCaps: [Character: Int] = [
        "Q": 1, "X": 1, "Z": 1, "J": 1, "K": 1
    ]

    /// Hard vowel cap per 7×7 board (49 tiles).
    static let maxVowels: Int = 20

    /// Set of vowel characters used for vowel-cap tracking.
    static let vowelSet: Set<Character> = ["A", "E", "I", "O", "U"]

    // MARK: Rarity gate tunables

    /// Probability of drawing from the extreme-rare pool (Q, Z) on any single draw.
    static let pExtreme: Double = 0.0045
    /// Net probability of drawing from the rare pool (J, X, K) on any single draw.
    static let pRareNet: Double = 0.012
    /// Upper cutoff for rare-pool draws (pExtreme + pRareNet).
    static let cutoffRare: Double = pExtreme + pRareNet

    /// Letters that appear only via the extreme-rare gate (pExtreme).
    static let extremeRares: [Character] = ["Q", "Z"]
    /// Letters that appear only via the rare gate (pRareNet).
    static let rares: [Character] = ["J", "X", "K"]
    /// Union of both rare tiers; used to build the normal pool and for cap checks.
    static let rareSet: Set<Character> = ["Q", "Z", "J", "X", "K"]

    private static let vowelFallbacks: [Character] = ["A", "E", "I", "O", "U"]
    private static let consonantFallbacks: [Character] = ["T", "N", "R", "S", "L"]

    /// Weighted letter distribution used to build the normal pool.
    /// Vowel target: ~40 % of bag weight; hard cap via maxVowels.
    /// Entries for Q/Z/J/X/K are kept for documentation but excluded from the
    /// normal pool — those letters only appear via the rarity gate above.
    static let defaultWeights: [(Character, Int)] = [
        // Vowels — ~40 % of total weight
        ("A", 11), ("E", 11), ("I", 9), ("O", 9), ("U", 6),
        // Common consonants — slightly boosted
        ("T", 10), ("N", 8), ("R", 8), ("S", 7), ("L", 6),
        // Medium-frequency consonants
        ("D", 4), ("G", 3), ("C", 3), ("M", 3), ("P", 3),
        // Lower-frequency consonants
        ("B", 2), ("F", 2), ("H", 2),
        // Uncommon — higher value, no cap; appear a few times per board
        ("V", 2), ("W", 2), ("Y", 3),
        // Rare / extreme-rare — excluded from the normal pool; gated via pRareNet / pExtreme.
        ("K", 2), ("J", 1), ("X", 1),
        ("Q", 1), ("Z", 1)
    ]
}
