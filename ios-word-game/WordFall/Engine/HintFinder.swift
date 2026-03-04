import Foundation

// MARK: - WordTrie

final class WordTrie {
    var children: [Character: WordTrie] = [:]
    var isWord: Bool = false

    func insert(_ word: String) {
        var node = self
        for ch in word {
            if node.children[ch] == nil {
                node.children[ch] = WordTrie()
            }
            node = node.children[ch]!
        }
        node.isWord = true
    }

    func child(for ch: Character) -> WordTrie? {
        children[ch]
    }
}

// MARK: - HintPath

struct HintPath {
    let indices: [Int]
    let word: String
}

// MARK: - HintFinder

enum HintFinder {
    /// Finds a playable 3-letter word path using the current board template's adjacency mode.
    ///
    /// Enumeration: for every ordered triple (i → j → k) where j is a template-valid
    /// neighbour of i and k is a template-valid neighbour of j (k ≠ i), check whether
    /// the tile letters form a dictionary word in either direction.
    ///
    /// Ranking (higher wins, first-found wins ties):
    ///   1. Path contains at least one `freshLocked` tile (+10 000)
    ///   2. Higher Scrabble letter-sum of the matched word
    ///   3. Lower start index (stability — no randomness)
    static func findHint3(state: GameState, dictionary: WordDictionary) -> HintPath? {
        let gridSize = state.boardTemplate.gridSize
        let adjacencyMode = state.boardTemplate.adjacency
        let tiles = state.tiles
        let total = gridSize * gridSize

        var best: (path: [Int], word: String, score: Int)? = nil

        for i in 0..<total {
            guard let tileI = tiles[i] else { continue }
            guard tileI.isLetterTile else { continue }
            for j in neighbors(of: i, gridSize: gridSize, mode: adjacencyMode) {
                guard let tileJ = tiles[j] else { continue }
                guard tileJ.isLetterTile else { continue }
                for k in neighbors(of: j, gridSize: gridSize, mode: adjacencyMode) {
                    guard k != i else { continue }
                    guard let tileK = tiles[k] else { continue }
                    guard tileK.isLetterTile else { continue }

                    let raw = String([tileI.letter, tileJ.letter, tileK.letter]).lowercased()
                    guard dictionary.contains(raw) else { continue }
                    let matched = raw

                    let path = [i, j, k]
                    let hasLocked = path.contains { tiles[$0]?.freshness == .freshLocked }
                    let letterSum = LetterValues.sum(for: matched)
                    let score = (hasLocked ? 10_000 : 0) + letterSum

                    if best == nil || score > best!.score {
                        best = (path, matched, score)
                    }
                }
            }
        }

        return best.map { HintPath(indices: $0.path, word: $0.word) }
    }

    /// Verifies that a hint path is still valid against the current board state.
    /// Returns `true` only if the path is exactly 3 template-adjacent distinct tiles
    /// whose letters form a forward dictionary word.
    static func validateHint(_ path: [Int], state: GameState, dictionary: WordDictionary) -> Bool {
        guard path.count == 3, Set(path).count == 3 else { return false }

        let gridSize = state.boardTemplate.gridSize
        let adjacencyMode = state.boardTemplate.adjacency
        for i in 1..<path.count {
            let a = path[i - 1], b = path[i]
            guard neighbors(of: a, gridSize: gridSize, mode: adjacencyMode).contains(b) else { return false }
        }

        guard let raw = Selection.word(from: state.tiles, indices: path) else { return false }
        return dictionary.contains(raw)
    }
}
