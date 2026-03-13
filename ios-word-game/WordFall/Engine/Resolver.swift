import Foundation

enum SubmissionRejectionReason: String {
    case invalidLength
    case outOfBounds
    case reusedTile
    case emptyTile
    case notInDictionary
    case mixedQuadrants
    case mixedPools
    case samePoolTwice
    case minimumWordLength
}

struct ResolverResult {
    let newState: GameState
    let events: [GameEvent]
    let accepted: Bool
    let acceptedWord: String?
    let rejectionReason: SubmissionRejectionReason?
    let scoreDelta: Int
    let movesDelta: Int
    let inkDelta: Int
    let clearedCount: Int
    let locksBrokenThisMove: Int
    let currentLockedCount: Int
    let lastSubmittedWord: String
}

enum Resolver {
    static let minWordLen = 4
    static let maxWordLen = 20
    static let targetLocks = GameState.defaultTargetLocks

    static let hardLockLetters: Set<Character> = ["Q", "Z", "X", "J", "K", "V", "W"]
    private static let preferredConsonants: Set<Character> = ["T", "N", "R", "S", "L", "D", "G", "C", "M", "P", "H", "B", "F", "Y"]

    static func initialState(
        rows: Int = GameState.defaultRows,
        cols: Int = GameState.defaultCols,
        template: BoardTemplate? = nil,
        moves: Int = GameState.defaultMoves,
        dictionary: WordDictionary,
        bag: inout LetterBag,
        lockObjectiveTarget: Int? = nil,
        generationProfile: BoardGenerationProfile = .fallback
    ) -> GameState {
        let resolvedTemplate: BoardTemplate
        if let template {
            resolvedTemplate = template
        } else {
            let size = max(rows, cols)
            resolvedTemplate = BoardTemplate.full(
                gridSize: size,
                id: "legacy_full_\(size)x\(size)",
                name: "Legacy Full \(size)x\(size)"
            )
        }
        let lockTarget = lockObjectiveTarget ?? targetLocks

        var initial = GameState(
            rows: resolvedTemplate.rows,
            cols: resolvedTemplate.cols,
            boardTemplate: resolvedTemplate,
            tiles: generateFilledTiles(
                template: resolvedTemplate,
                dictionary: dictionary,
                bag: &bag,
                generationProfile: generationProfile
            ),
            score: 0,
            moves: moves,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: lockTarget
        )

        placeInitialLocks(state: &initial, requiredLocks: lockTarget)

        #if DEBUG
        let rareTally = initial.tiles.compactMap { $0 }.reduce(into: [Character: Int]()) { tally, tile in
            let letter = tile.letter
            if LetterBag.rareCaps.keys.contains(letter) || ["V", "W", "Y"].contains(letter) {
                tally[letter, default: 0] += 1
            }
        }
        let tallyStr = rareTally.keys.sorted().map { "\($0):\(rareTally[$0]!)" }.joined(separator: " ")
        print("[Board] rare/uncommon tile counts — \(tallyStr.isEmpty ? "none" : tallyStr)")
        #endif

        return initial
    }

    static func minimumWordLength(for template: BoardTemplate) -> Int {
        switch template.specialRule {
        case .minimumWordLength(let length):
            return max(minWordLen, min(length, maxWordLen))
        default:
            return minWordLen
        }
    }

    static func reduce(
        state: GameState,
        action: GameAction,
        dictionary: WordDictionary,
        bag: inout LetterBag
    ) -> ResolverResult {
        switch action {
        case .submitPath(let indices):
            return reducePath(state: state, path: indices, dictionary: dictionary, bag: &bag)
        }
    }

    private static func reducePath(
        state: GameState,
        path: [Int],
        dictionary: WordDictionary,
        bag: inout LetterBag
    ) -> ResolverResult {
        if let rejection = validatePath(path, template: state.boardTemplate) {
            return rejected(state: state, reason: rejection, path: path, submittedWord: "")
        }

        guard let rawWord = Selection.word(from: state.tiles, indices: path) else {
            return rejected(state: state, reason: .emptyTile, path: path, submittedWord: "")
        }

        #if DEBUG
        let reversedWord = String(rawWord.reversed())
        let matched: String
        if dictionary.contains(rawWord) {
            matched = "forward"
        } else if dictionary.contains(reversedWord) {
            matched = "reverse (rejected — forward-only)"
        } else {
            matched = "none"
        }
        print("[Resolver] path=\(path) word='\(rawWord)' reversed='\(reversedWord)' match=\(matched)")
        #endif

        guard dictionary.contains(rawWord) else {
            return rejected(state: state, reason: .notInDictionary, path: path, submittedWord: rawWord)
        }
        let acceptedWord = rawWord

        var newState = state
        var events: [GameEvent] = []
        var clearIndices: [Int] = []
        var lockBreakIndices: [Int] = []

        for index in path {
            guard let tile = newState.tiles[index], tile.isLetterTile else { continue }
            newState.usedTileIds.insert(tile.id)
            if tile.freshness == .freshLocked {
                lockBreakIndices.append(index)
            }
            clearIndices.append(index)
        }

        let locksBrokenThisMove = lockBreakIndices.count
        if !lockBreakIndices.isEmpty {
            events.append(.lockBreak(indices: lockBreakIndices.sorted()))
        }

        let letterSum = LetterValues.sum(for: acceptedWord)
        let points = Scoring.baseWordPoints(letterSum: letterSum, length: acceptedWord.count)
        let ink = Scoring.inkPoints(letterSum: letterSum, length: acceptedWord.count, isCascade: false)
        newState.score += points
        newState.inkPoints += ink
        newState.totalLocksBroken += locksBrokenThisMove

        for index in clearIndices {
            newState.tiles[index] = nil
        }

        if !clearIndices.isEmpty {
            events.append(.clear(ClearEvent(
                indices: clearIndices.sorted(),
                word: acceptedWord,
                awardedPoints: points,
                isCascade: false,
                cascadeStep: 0
            )))
        }

        applyGravityAndSpawn(state: &newState, events: &events, bag: &bag)

        let scoreDelta = newState.score - state.score
        let movesDelta = newState.moves - state.moves
        let inkDelta = newState.inkPoints - state.inkPoints
        let currentLockedCount = countLockedTiles(in: newState.tiles)

        return ResolverResult(
            newState: newState,
            events: events,
            accepted: true,
            acceptedWord: acceptedWord,
            rejectionReason: nil,
            scoreDelta: scoreDelta,
            movesDelta: movesDelta,
            inkDelta: inkDelta,
            clearedCount: clearIndices.count,
            locksBrokenThisMove: locksBrokenThisMove,
            currentLockedCount: currentLockedCount,
            lastSubmittedWord: rawWord
        )
    }

    private static func applyGravityAndSpawn(state: inout GameState, events: inout [GameEvent], bag: inout LetterBag) {
        let gravityResult = Gravity.apply(
            tiles: state.tiles,
            rows: state.rows,
            cols: state.cols,
            template: state.boardTemplate
        )
        state.tiles = gravityResult.tiles

        if !gravityResult.drops.isEmpty {
            events.append(.drop(gravityResult.drops))
        }

        let spawnResult = Gravity.spawn(
            into: state.tiles,
            emptyIndices: gravityResult.emptyIndices,
            rows: state.rows,
            cols: state.cols,
            template: state.boardTemplate,
            bag: &bag
        )

        state.tiles = spawnResult.tiles
        if !spawnResult.spawns.isEmpty {
            events.append(.spawn(spawnResult.spawns))
        }
    }

    private static func placeInitialLocks(state: inout GameState, requiredLocks: Int) {
        let currentLockedCount = countLockedTiles(in: state.tiles)
        guard currentLockedCount < requiredLocks else { return }

        let needed = requiredLocks - currentLockedCount
        let candidates = lockCandidates(tiles: state.tiles, usedTileIds: state.usedTileIds)
        guard !candidates.isEmpty else { return }

        for index in candidates.prefix(needed) {
            guard var tile = state.tiles[index] else { continue }
            tile.freshness = .freshLocked
            state.tiles[index] = tile
        }
    }

    private static func lockCandidates(tiles: [Tile?], usedTileIds: Set<UUID>) -> [Int] {
        var prioritized: [(index: Int, priority: Int)] = []

        for index in tiles.indices {
            guard let tile = tiles[index] else { continue }
            guard tile.kind == .normal else { continue }
            guard tile.freshness == .normal else { continue }
            guard !usedTileIds.contains(tile.id) else { continue }
            guard !hardLockLetters.contains(tile.letter) else { continue }

            prioritized.append((index, lockPriority(for: tile.letter)))
        }

        prioritized.shuffle()
        prioritized.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.index < rhs.index
        }

        return prioritized.map(\.index)
    }

    private static func lockPriority(for letter: Character) -> Int {
        if LetterBag.vowelSet.contains(letter) {
            return 0
        }
        if preferredConsonants.contains(letter) {
            return 1
        }
        return 2
    }

    private static func countLockedTiles(in tiles: [Tile?]) -> Int {
        tiles.compactMap { $0 }.filter { $0.isLetterTile && $0.freshness == .freshLocked }.count
    }

    static func satisfiesGenerationConstraints(
        tiles: [Tile?],
        template: BoardTemplate,
        dictionary: WordDictionary
    ) -> Bool {
        guard satisfiesRegionalVowelMinimums(tiles: tiles, template: template) else {
            return false
        }

        switch template.specialRule {
        case .alternatingPools:
            return alternatingPoolsMeetGenerationConstraints(
                tiles: tiles,
                template: template,
                dictionary: dictionary
            )
        default:
            return true
        }
    }

    static func solvableWordsByRegion(
        in tiles: [Tile?],
        template: BoardTemplate,
        dictionary: WordDictionary,
        lengths: ClosedRange<Int> = 4...6
    ) -> [Int: Set<String>] {
        guard !template.regions.isEmpty else { return [:] }

        let candidateWords = lengths.flatMap { dictionary.words(ofLength: $0) }.map { $0.uppercased() }
        var result: [Int: Set<String>] = [:]

        for regionID in template.regionIDs {
            let regionCounts = letterCountsForRegion(regionID, in: tiles, template: template)
            guard !regionCounts.isEmpty else {
                result[regionID] = []
                continue
            }

            let matches = candidateWords.filter { word in
                let neededCounts = letterCounts(for: Array(word))
                return neededCounts.allSatisfy { letter, count in
                    regionCounts[letter, default: 0] >= count
                }
            }
            result[regionID] = Set(matches)
        }

        return result
    }

    private static func generateFilledTiles(
        template: BoardTemplate,
        dictionary: WordDictionary,
        bag: inout LetterBag,
        generationProfile: BoardGenerationProfile
    ) -> [Tile?] {
        if template.specialRule == .alternatingPools,
           let alternatingTiles = generateAlternatingPoolsTiles(template: template, dictionary: dictionary, bag: &bag) {
            return alternatingTiles
        }

        let maxAttempts = max(1, generationProfile.attemptBudget)

        var bestTiles: [Tile?] = []

        for attempt in 0..<maxAttempts {
            let candidate = generateFilledTilesOnce(template: template, bag: &bag)
            let passesConstraints = satisfiesGenerationConstraints(tiles: candidate, template: template, dictionary: dictionary)
            let passesQualityFloor = boardMeetsQualityFloor(
                tiles: candidate,
                dictionary: dictionary,
                generationProfile: generationProfile
            )
            if passesConstraints && passesQualityFloor {
                #if DEBUG
                if attempt > 0 {
                    print("[BoardGen] quality floor passed on attempt \(attempt + 1)/\(maxAttempts)")
                }
                #endif
                return candidate
            }
            bestTiles = candidate
            #if DEBUG
            print("[BoardGen] quality floor retry \(attempt + 1)/\(maxAttempts): constraints=\(passesConstraints) quality=\(passesQualityFloor)")
            #endif
        }

        #if DEBUG
        print("[BoardGen] quality floor: all \(maxAttempts) attempts failed, using best candidate")
        #endif
        return bestTiles
    }

    /// Lightweight quality-floor check used by bucket-based generation.
    /// Boards are filtered by letter-frequency solvability instead of path-search so
    /// the retry loop stays cheap and tunable.
    private static func boardMeetsQualityFloor(
        tiles: [Tile?],
        dictionary: WordDictionary,
        generationProfile: BoardGenerationProfile
    ) -> Bool {
        var counts: [Character: Int] = [:]
        for tile in tiles.compactMap({ $0 }) {
            guard tile.isLetterTile else { continue }
            counts[tile.letter, default: 0] += 1
        }

        let rareCount = counts.reduce(0) { partial, entry in
            partial + (LetterBag.rareSet.contains(entry.key) ? entry.value : 0)
        }
        if rareCount > generationProfile.maxRareLetters {
            return false
        }

        let consonantCounts = counts.filter { !LetterBag.vowelSet.contains($0.key) }
        if (consonantCounts.values.max() ?? 0) > generationProfile.maxConsonantDuplicates {
            return false
        }

        var solvableCount = 0
        for length in 4...6 {
            for word in dictionary.words(ofLength: length) {
                let wordKey = word.uppercased()
                let wordCounts = wordKey.reduce(into: [Character: Int]()) { $0[$1, default: 0] += 1 }
                if wordCounts.allSatisfy({ counts[$0.key, default: 0] >= $0.value }) {
                    solvableCount += 1
                    if solvableCount >= generationProfile.minimumMediumWords {
                        return true
                    }
                }
            }
        }
        return false
    }

    private static func generateFilledTilesOnce(template: BoardTemplate, bag: inout LetterBag) -> [Tile?] {
        let size = template.gridSize
        var tiles = [Tile?](repeating: nil, count: size * size)
        var existingCounts: [Character: Int] = [:]

        for index in tiles.indices {
            guard template.isPlayable(index) else {
                tiles[index] = nil
                continue
            }

            if template.isStone(index) {
                tiles[index] = Tile.stone()
                continue
            }

            tiles[index] = bag.nextTile(respecting: LetterBag.rareCaps, existingCounts: &existingCounts)
        }

        return tiles
    }

    private static func satisfiesRegionalVowelMinimums(tiles: [Tile?], template: BoardTemplate) -> Bool {
        guard template.minimumVowelsPerRegion > 0, !template.regions.isEmpty else { return true }

        var counts: [Int: Int] = [:]
        for (index, regionID) in template.regions {
            guard let tile = tiles[index], tile.isLetterTile else { continue }
            if LetterBag.vowelSet.contains(tile.letter) {
                counts[regionID, default: 0] += 1
            }
        }

        return template.regionIDs.allSatisfy { counts[$0, default: 0] >= template.minimumVowelsPerRegion }
    }

    private static func alternatingPoolsMeetGenerationConstraints(
        tiles: [Tile?],
        template: BoardTemplate,
        dictionary: WordDictionary
    ) -> Bool {
        let solvable = solvableWordsByRegion(in: tiles, template: template, dictionary: dictionary)

        return template.regionIDs.allSatisfy { regionID in
            let counts = letterCountsForRegion(regionID, in: tiles, template: template)
            let vowelCount = counts.reduce(0) { partial, entry in
                partial + (LetterBag.vowelSet.contains(entry.key) ? entry.value : 0)
            }
            let consonantCounts = counts.filter { !LetterBag.vowelSet.contains($0.key) }
            let consonantCount = consonantCounts.values.reduce(0, +)
            let maxConsonantDuplicates = consonantCounts.values.max() ?? 0

            return vowelCount >= 2
                && consonantCount >= 6
                && maxConsonantDuplicates <= 2
                && solvable[regionID, default: []].count >= 4
        }
    }

    private static func generateAlternatingPoolsTiles(
        template: BoardTemplate,
        dictionary: WordDictionary,
        bag: inout LetterBag
    ) -> [Tile?]? {
        let totalCells = template.gridSize * template.gridSize
        var tiles = [Tile?](repeating: nil, count: totalCells)

        for index in 0..<totalCells {
            guard template.isPlayable(index) else { continue }
            if template.isStone(index) {
                tiles[index] = Tile.stone()
            }
        }

        for regionID in template.regionIDs {
            let regionIndices = template.regions
                .compactMap { $0.value == regionID ? $0.key : nil }
                .sorted()
            guard let letters = generateAlternatingPoolLetters(
                regionSize: regionIndices.count,
                dictionary: dictionary,
                bag: &bag
            ) else {
                return nil
            }

            for (offset, index) in regionIndices.enumerated() {
                tiles[index] = Tile(id: UUID(), letter: letters[offset])
            }
        }

        return satisfiesGenerationConstraints(tiles: tiles, template: template, dictionary: dictionary) ? tiles : nil
    }

    private static func generateAlternatingPoolLetters(
        regionSize: Int,
        dictionary: WordDictionary,
        bag: inout LetterBag
    ) -> [Character]? {
        let candidateWords = (4...6).flatMap { dictionary.words(ofLength: $0) }.map { $0.uppercased() }
        guard candidateWords.count >= 4 else { return nil }

        for _ in 0..<120 {
            let shuffledWords = candidateWords.shuffled()
            var selectedWords: [String] = []
            var requiredCounts: [Character: Int] = [:]

            for word in shuffledWords {
                let merged = mergedMaximumLetterCounts(current: requiredCounts, with: word)
                let consonantCounts = merged.filter { !LetterBag.vowelSet.contains($0.key) }
                guard merged.values.reduce(0, +) <= regionSize else { continue }
                guard (consonantCounts.values.max() ?? 0) <= 2 else { continue }
                selectedWords.append(word)
                requiredCounts = merged
                if selectedWords.count == 4 {
                    break
                }
            }

            guard selectedWords.count == 4 else { continue }

            var letters = expandedLetters(from: requiredCounts)
            var counts = requiredCounts

            while letters.count < regionSize {
                let vowelCount = counts.reduce(0) { partial, entry in
                    partial + (LetterBag.vowelSet.contains(entry.key) ? entry.value : 0)
                }
                let consonantCount = counts.reduce(0) { partial, entry in
                    partial + (LetterBag.vowelSet.contains(entry.key) ? 0 : entry.value)
                }

                let nextLetter: Character
                if vowelCount < 2 {
                    nextLetter = randomVowel(using: &bag)
                } else if consonantCount < 6 {
                    nextLetter = randomConsonant(currentCounts: counts, using: &bag)
                } else if Bool.random() {
                    nextLetter = randomVowel(using: &bag)
                } else {
                    nextLetter = randomConsonant(currentCounts: counts, using: &bag)
                }

                if !LetterBag.vowelSet.contains(nextLetter), counts[nextLetter, default: 0] >= 2 {
                    continue
                }

                counts[nextLetter, default: 0] += 1
                letters.append(nextLetter)
            }

            letters.shuffle()
            let regionCounts = letterCounts(for: letters)
            let solvableCount = candidateWords.filter { word in
                let needed = letterCounts(for: Array(word))
                return needed.allSatisfy { letter, count in
                    regionCounts[letter, default: 0] >= count
                }
            }.count

            let consonantCounts = regionCounts.filter { !LetterBag.vowelSet.contains($0.key) }
            let consonantCount = consonantCounts.values.reduce(0, +)
            let vowelCount = regionCounts.filter { LetterBag.vowelSet.contains($0.key) }.values.reduce(0, +)
            if vowelCount >= 2, consonantCount >= 6, (consonantCounts.values.max() ?? 0) <= 2, solvableCount >= 4 {
                return letters
            }
        }

        return nil
    }

    private static func mergedMaximumLetterCounts(
        current: [Character: Int],
        with word: String
    ) -> [Character: Int] {
        var merged = current
        let wordCounts = letterCounts(for: Array(word))
        for (letter, count) in wordCounts {
            merged[letter] = max(merged[letter, default: 0], count)
        }
        return merged
    }

    private static func expandedLetters(from counts: [Character: Int]) -> [Character] {
        counts.keys.sorted().flatMap { letter in
            Array(repeating: letter, count: counts[letter, default: 0])
        }
    }

    private static func randomVowel(using bag: inout LetterBag) -> Character {
        let vowels = Array(LetterBag.vowelSet).sorted()
        for _ in 0..<8 {
            let candidate = bag.nextLetter()
            if LetterBag.vowelSet.contains(candidate) {
                return candidate
            }
        }
        return vowels.randomElement() ?? "E"
    }

    private static func randomConsonant(
        currentCounts: [Character: Int],
        using bag: inout LetterBag
    ) -> Character {
        let fallbackConsonants = Array(preferredConsonants).sorted()
        for _ in 0..<16 {
            let candidate = bag.nextLetter()
            if LetterBag.vowelSet.contains(candidate) {
                continue
            }
            if currentCounts[candidate, default: 0] < 2 {
                return candidate
            }
        }
        return fallbackConsonants.first(where: { currentCounts[$0, default: 0] < 2 }) ?? "T"
    }

    private static func letterCountsForRegion(
        _ regionID: Int,
        in tiles: [Tile?],
        template: BoardTemplate
    ) -> [Character: Int] {
        let letters = template.regions.compactMap { index, candidateRegionID -> Character? in
            guard candidateRegionID == regionID else { return nil }
            guard let tile = tiles[index], tile.isLetterTile else { return nil }
            return tile.letter
        }
        return letterCounts(for: letters)
    }

    private static func letterCounts(for letters: [Character]) -> [Character: Int] {
        letters.reduce(into: [Character: Int]()) { counts, letter in
            counts[letter, default: 0] += 1
        }
    }

    private static func validatePath(_ path: [Int], template: BoardTemplate) -> SubmissionRejectionReason? {
        let minimumLength = minimumWordLength(for: template)

        if path.count < minimumLength {
            switch template.specialRule {
            case .minimumWordLength:
                return .minimumWordLength
            default:
                return .invalidLength
            }
        }

        guard path.count <= maxWordLen else {
            return .invalidLength
        }

        let boardSize = template.gridSize * template.gridSize
        guard path.allSatisfy({ (0..<boardSize).contains($0) }) else {
            return .outOfBounds
        }

        guard Set(path).count == path.count else {
            return .reusedTile
        }

        switch template.specialRule {
        case .singlePoolPerWord, .alternatingPools:
            let regions = Set(path.compactMap { template.regionID(for: $0) })
            if regions.count > 1 {
                return .mixedPools
            }
        default:
            break
        }

        return nil
    }

    private static func rejected(
        state: GameState,
        reason: SubmissionRejectionReason,
        path: [Int],
        submittedWord: String
    ) -> ResolverResult {
        return ResolverResult(
            newState: state,
            events: [],
            accepted: false,
            acceptedWord: nil,
            rejectionReason: reason,
            scoreDelta: 0,
            movesDelta: 0,
            inkDelta: 0,
            clearedCount: 0,
            locksBrokenThisMove: 0,
            currentLockedCount: countLockedTiles(in: state.tiles),
            lastSubmittedWord: submittedWord.isEmpty ? "" : submittedWord
        )
    }
}
