import Foundation

// MARK: - MilestoneID

enum MilestoneID: String, Codable, CaseIterable {
    case break50Locks
    case make50SixLetterWords
    case useLetterAIn100Words
}

// MARK: - Milestone definition

struct Milestone {
    let id: MilestoneID
    /// Human-readable description shown in RunSummaryView.
    let description: String
    /// The modifier that gets added to unlockedPerks when this milestone is reached.
    let unlocksPerkID: PerkID
    /// The numeric threshold that must be reached to unlock.
    let threshold: Int
}

// MARK: - MilestoneID → definition

extension MilestoneID {
    var definition: Milestone {
        switch self {
        case .break50Locks:
            return Milestone(id: .break50Locks,
                description: "Break 50 locks total",
                unlocksPerkID: .lockSplash,
                threshold: 50)
        case .make50SixLetterWords:
            return Milestone(id: .make50SixLetterWords,
                description: "Make 50 six-letter words",
                unlocksPerkID: .bigGame,
                threshold: 50)
        case .useLetterAIn100Words:
            return Milestone(id: .useLetterAIn100Words,
                description: "Use letter A in 100 words",
                unlocksPerkID: .echoChamber,
                threshold: 100)
        }
    }
}
