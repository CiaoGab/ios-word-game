import Foundation

enum ChallengeRoundKind: String, Codable, Equatable {
    case triplePoolBoard
    case pyramidBoard
    case taxRound
    case alternatingPools
    case finalExam
}

enum ChallengeFamily: String, Equatable {
    case poolBoard
    case shapeBoard
    case ruleBoard
    case finalCheckpoint
}

enum ChallengeSpecialRule: Equatable {
    case none
    case singlePoolPerWord
    case taxSubmitCost
    case alternatingPools
    case minimumWordLength(Int)

    var hudSummary: String {
        switch self {
        case .none:
            return "Special board"
        case .singlePoolPerWord:
            return "One pool per word"
        case .taxSubmitCost:
            return "Base submit cost is 2"
        case .alternatingPools:
            return "Alternate left and right pools"
        case .minimumWordLength(let length):
            return "Words must be \(length)+ letters"
        }
    }
}

protocol ChallengeRound {
    var kind: ChallengeRoundKind { get }
    var family: ChallengeFamily { get }
    var boardTemplate: BoardTemplate { get }
    var specialRule: ChallengeSpecialRule { get }
    var modifiedScoreTargetMultiplier: Double { get }
    var modifiedMoves: Int { get }
    var modifiedLockCount: Int { get }
    var displayName: String { get }
    var ruleSummary: String { get }
    var objective: RoundObjectiveDefinition? { get }
}

struct ChallengeSecondaryPresentation: Equatable {
    let label: String
    let text: String
}

struct ChallengeRoundDefinition: ChallengeRound, Equatable {
    let kind: ChallengeRoundKind
    let family: ChallengeFamily
    let boardTemplate: BoardTemplate
    let specialRule: ChallengeSpecialRule
    let modifiedScoreTargetMultiplier: Double
    let modifiedMoves: Int
    let modifiedLockCount: Int
    let displayName: String
    let ruleSummary: String
    let objective: RoundObjectiveDefinition?

    var primaryRuleText: String? {
        let trimmed = ruleSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var secondaryPresentation: ChallengeSecondaryPresentation? {
        guard let objective else { return nil }
        return ChallengeSecondaryPresentation(
            label: objective.presentationLabel,
            text: objective.shortDescription
        )
    }
}

enum ChallengeRoundResolver {
    static func resolve(roundIndex: Int) -> ChallengeRoundDefinition? {
        let plan = RunState.progression(for: roundIndex)
        guard plan.isMilestoneRound, let kind = plan.challengeKind else {
            return nil
        }

        let template = template(for: kind)
        let scoreMultiplier = plan.bucketConfig.scoreMultiplier * plan.bucketConfig.milestoneScoreMultiplier
        let adjustedBase = plan.bucketConfig.scoreMultiplier

        return ChallengeRoundDefinition(
            kind: kind,
            family: family(for: kind),
            boardTemplate: template,
            specialRule: template.specialRule,
            modifiedScoreTargetMultiplier: adjustedBase == 0 ? 1.0 : scoreMultiplier / adjustedBase,
            modifiedMoves: plan.bucketConfig.milestoneMoves - plan.bucketConfig.normalMoves,
            modifiedLockCount: plan.bucketConfig.milestoneLockBonus,
            displayName: displayName(for: kind),
            ruleSummary: baseRuleSummary(for: kind, template: template),
            objective: plan.objective
        )
    }

    private static func family(for kind: ChallengeRoundKind) -> ChallengeFamily {
        switch kind {
        case .triplePoolBoard, .alternatingPools:
            return .poolBoard
        case .pyramidBoard:
            return .shapeBoard
        case .taxRound:
            return .ruleBoard
        case .finalExam:
            return .finalCheckpoint
        }
    }

    private static func displayName(for kind: ChallengeRoundKind) -> String {
        switch kind {
        case .triplePoolBoard:
            return "TRIPLE POOLS"
        case .pyramidBoard:
            return "PYRAMID BOARD"
        case .taxRound:
            return "TAX ROUND"
        case .alternatingPools:
            return "ALTERNATING POOLS"
        case .finalExam:
            return "FINAL EXAM"
        }
    }

    private static func baseRuleSummary(
        for kind: ChallengeRoundKind,
        template: BoardTemplate
    ) -> String {
        switch kind {
        case .pyramidBoard:
            return "Shape board only"
        default:
            return template.specialRule.hudSummary
        }
    }

    private static func template(for kind: ChallengeRoundKind) -> BoardTemplate {
        switch kind {
        case .triplePoolBoard:
            return triplePoolTemplate
        case .pyramidBoard:
            return pyramidBoardTemplate
        case .taxRound:
            return taxRoundTemplate
        case .alternatingPools:
            return alternatingPoolsTemplate
        case .finalExam:
            return finalExamTemplate
        }
    }

    private static let triplePoolTemplate: BoardTemplate = {
        let size = 7
        let rows: [[Int]] = [
            [0, 1, 2, 4, 5, 6],
            [0, 1, 2, 4, 5, 6],
            [0, 1, 2, 4, 5, 6],
            [],
            [0, 1, 2, 3, 4, 5],
            [0, 1, 2, 3, 4, 5],
            [0, 1, 2, 3, 4, 5]
        ]

        var regions: [Int: Int] = [:]
        for row in 0...2 {
            for col in 0...2 {
                regions[row * size + col] = 0
            }
            for col in 4...6 {
                regions[row * size + col] = 1
            }
        }
        for row in 4...6 {
            for col in 0...5 {
                regions[row * size + col] = 2
            }
        }

        return BoardTemplate(
            id: "challenge10_triple_pools",
            name: "Challenge 10 Triple Pools",
            gridSize: size,
            mask: maskRows(rows, size: size),
            specialRule: .singlePoolPerWord,
            regions: regions,
            minimumVowelsPerRegion: 2,
            visualStyle: .triplePoolsBalanced
        )
    }()

    private static let pyramidBoardTemplate: BoardTemplate = {
        let size = 7
        let rows: [[Int]] = [
            [3],
            [2, 3, 4],
            [1, 2, 3, 4, 5],
            [1, 2, 3, 4, 5],
            [0, 1, 2, 3, 4, 5, 6],
            [0, 1, 2, 3, 4, 5, 6],
            [0, 1, 2, 3, 4, 5, 6]
        ]
        let mask = maskRows(rows, size: size)
        let regions = Dictionary(uniqueKeysWithValues: mask.map { ($0, 0) })

        return BoardTemplate(
            id: "challenge20_pyramid_board",
            name: "Challenge 20 Pyramid Board",
            gridSize: size,
            mask: mask,
            regions: regions,
            minimumVowelsPerRegion: 7
        )
    }()

    private static let taxRoundTemplate: BoardTemplate = .full(
        gridSize: 7,
        id: "challenge30_tax_round",
        name: "Challenge 30 Tax Round",
        specialRule: .taxSubmitCost
    )

    private static let alternatingPoolsTemplate: BoardTemplate = {
        let size = 7
        let rows = Array(repeating: [0, 1, 2, 4, 5, 6], count: size)
        let mask = maskRows(rows, size: size)
        var regions: [Int: Int] = [:]

        for row in 0..<size {
            for col in 0...2 {
                regions[row * size + col] = 0
            }
            for col in 4...6 {
                regions[row * size + col] = 1
            }
        }

        return BoardTemplate(
            id: "challenge40_alternating_pools",
            name: "Challenge 40 Alternating Pools",
            gridSize: size,
            mask: mask,
            specialRule: .alternatingPools,
            regions: regions,
            minimumVowelsPerRegion: 2
        )
    }()

    private static let finalExamTemplate: BoardTemplate = {
        let size = 7
        let mask = diamondMask(size, radius: 4)
        let stones = Set([
            1 * size + 3,
            3 * size + 1,
            3 * size + 5,
            5 * size + 3
        ])
        let regions = Dictionary(uniqueKeysWithValues: mask.map { ($0, 0) })

        return BoardTemplate(
            id: "challenge50_final_exam",
            name: "Challenge 50 Final Exam",
            gridSize: size,
            adjacency: .hvAndDiagonals,
            mask: mask,
            stones: stones,
            specialRule: .minimumWordLength(6),
            regions: regions,
            minimumVowelsPerRegion: 12
        )
    }()

    private static func placeholderChallengeBoard(id: String, name: String) -> BoardTemplate {
        BoardTemplate(
            id: id,
            name: name,
            gridSize: 7,
            mask: Set(0..<(7 * 7))
        )
    }

    private static func maskRows(_ rows: [[Int]], size: Int) -> Set<Int> {
        var result: Set<Int> = []
        for (row, cols) in rows.enumerated() where row < size {
            for col in cols where col >= 0 && col < size {
                result.insert(row * size + col)
            }
        }
        return result
    }

    private static func diamondMask(_ size: Int, radius: Int) -> Set<Int> {
        let center = size / 2
        var result: Set<Int> = []
        for row in 0..<size {
            for col in 0..<size {
                if abs(row - center) + abs(col - center) <= radius {
                    result.insert(row * size + col)
                }
            }
        }
        return result
    }
}
