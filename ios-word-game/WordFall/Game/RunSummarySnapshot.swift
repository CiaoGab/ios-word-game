import Foundation

struct RunSummarySnapshot: Equatable {
    let wonRun: Bool
    let totalScore: Int
    let xpEarned: Int
    let totalXPAfterRun: Int
    let roundsCleared: Int
    let totalRounds: Int
    let roundReached: Int
    let locksBroken: Int
    let wordsBuilt: Int
    let bestWord: String
    let bestWordScore: Int
    let challengeRoundsCleared: Int
    let rareLetterWordUsed: Bool
    let newUnlocks: [ProfileUnlockID]

    var roundsProgressText: String {
        "\(roundsCleared)/\(totalRounds)"
    }
}
