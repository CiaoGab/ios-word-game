import Foundation
import Testing
@testable import ios_word_game

struct ios_word_gameTests {
    private func makeTile(_ letter: Character, freshness: TileFreshness = .normal, id: UUID = UUID()) -> Tile {
        Tile(id: id, letter: letter, freshness: freshness)
    }

    private func makeState(rows: Int, cols: Int, tiles: [Tile?]) -> GameState {
        GameState(
            rows: rows,
            cols: cols,
            tiles: tiles,
            score: 0,
            moves: 5,
            inkPoints: 0,
            usedTileIds: [],
            totalLocksBroken: 0,
            lockObjectiveTarget: 6
        )
    }

    @Test func gravityCompactionDropsTilesToBottom() {
        let rows = 4
        let cols = 1

        let a = Tile(id: UUID(), letter: "A")
        let b = Tile(id: UUID(), letter: "B")

        let tiles: [Tile?] = [a, nil, b, nil]
        let result = Gravity.apply(tiles: tiles, rows: rows, cols: cols)

        #expect(result.tiles[0] == nil)
        #expect(result.tiles[1] == nil)
        #expect(result.tiles[2]?.id == a.id)
        #expect(result.tiles[3]?.id == b.id)
        #expect(result.drops.count == 2)
    }

    @Test func resolverRejectsShortPath() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let state = makeState(rows: 1, cols: 3, tiles: [makeTile("C"), makeTile("A"), makeTile("T")])

        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(!result.accepted)
        #expect(result.rejectionReason == .invalidLength)
        #expect(result.movesDelta == 0)
        #expect(result.events.isEmpty)
    }

    @Test func freshLockedTilesBreakButDoNotClear() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let tileIDs = [UUID(), UUID(), UUID()]

        let tiles: [Tile?] = [
            makeTile("C", freshness: .freshLocked, id: tileIDs[0]),
            makeTile("A", freshness: .freshLocked, id: tileIDs[1]),
            makeTile("T", freshness: .freshLocked, id: tileIDs[2])
        ]

        let state = makeState(rows: 1, cols: 3, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 0)
        #expect(result.locksBrokenThisMove == 3)
        #expect(result.movesDelta == -1)
        #expect(result.newState.totalLocksBroken == 3)

        for index in 0..<3 {
            #expect(result.newState.tiles[index]?.id == tileIDs[index])
            #expect(result.newState.tiles[index]?.freshness == .freshUnlocked)
        }

        guard case .lockBreak(let indices) = result.events.first else {
            Issue.record("Expected lockBreak event")
            return
        }
        #expect(indices == [0, 1, 2])
    }

    @Test func mixedFreshnessClearsOnlyUnlockedAndNormal() {
        var bag = LetterBag(weights: [("Z", 1)])
        let dictionary = WordDictionary(words: ["cat"])
        let lockedID = UUID()

        let tiles: [Tile?] = [
            makeTile("C", freshness: .normal),
            makeTile("A", freshness: .freshUnlocked),
            makeTile("T", freshness: .freshLocked, id: lockedID)
        ]

        let state = makeState(rows: 1, cols: 3, tiles: tiles)
        let result = Resolver.reduce(
            state: state,
            action: .submitPath(indices: [0, 1, 2]),
            dictionary: dictionary,
            bag: &bag
        )

        #expect(result.accepted)
        #expect(result.clearedCount == 2)
        #expect(result.locksBrokenThisMove == 1)
        #expect(result.newState.tiles[2]?.id == lockedID)
        #expect(result.newState.tiles[2]?.freshness == .freshUnlocked)

        let clearEvents = result.events.compactMap { event -> ClearEvent? in
            guard case .clear(let clear) = event else { return nil }
            return clear
        }
        #expect(clearEvents.first?.indices == [0, 1])
    }

    @Test func initialStateHasTargetLockFloor() {
        var bag = LetterBag()
        let dictionary = WordDictionary(words: ["cat", "game", "word"])
        let state = Resolver.initialState(rows: 7, cols: 7, dictionary: dictionary, bag: &bag)

        let lockedCount = state.tiles.compactMap { $0 }.filter { $0.freshness == .freshLocked }.count
        #expect(lockedCount >= GameState.defaultTargetLocks)
    }
}
