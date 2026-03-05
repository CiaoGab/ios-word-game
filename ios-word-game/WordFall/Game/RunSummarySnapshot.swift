import Foundation

struct RunSummarySnapshot: Equatable {
    let wonRun: Bool
    let totalScore: Int
    let boardsCleared: Int
    let totalBoards: Int
    let boardReached: Int
    let locksBroken: Int
    let wordsBuilt: Int
    let bestWord: String
    let bestWordScore: Int

    var boardsProgressText: String {
        "\(boardsCleared)/\(totalBoards)"
    }
}
