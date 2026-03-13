import Foundation

enum LifetimeMilestoneID: String, Codable, CaseIterable, Hashable, Identifiable {
    case build100Words
    case break150Locks
    case use25RareLetterWords
    case reachRound20

    var id: String { rawValue }

    var title: String {
        switch self {
        case .build100Words:
            return "Build 100 Words"
        case .break150Locks:
            return "Break 150 Locks"
        case .use25RareLetterWords:
            return "Use 25 Rare-Letter Words"
        case .reachRound20:
            return "Reach Round 20"
        }
    }

    var effectDescription: String {
        switch self {
        case .build100Words:
            return "+1 starting shuffle every round"
        case .break150Locks:
            return "Once per round, locked submit cost -1"
        case .use25RareLetterWords:
            return "+5% rare-letter spawn rate"
        case .reachRound20:
            return "+1 move at the start of challenge rounds"
        }
    }

    var threshold: Int {
        switch self {
        case .build100Words:
            return 100
        case .break150Locks:
            return 150
        case .use25RareLetterWords:
            return 25
        case .reachRound20:
            return 20
        }
    }

    func progressValue(from stats: PlayerProfile.Stats) -> Int {
        switch self {
        case .build100Words:
            return stats.totalWordsBuilt
        case .break150Locks:
            return stats.totalLocksBroken
        case .use25RareLetterWords:
            return stats.totalRareLetterWords
        case .reachRound20:
            return stats.highestRoundReached
        }
    }
}
