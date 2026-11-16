import Foundation

public final class Player {
    public let id: String
    public let name: String
    public let strategy: PlayerStrategy
    public private(set) var score: Int

    public init(id: String = UUID().uuidString, name: String, strategy: PlayerStrategy, startingScore: Int = 0) {
        self.id = id
        self.name = name
        self.strategy = strategy
        self.score = startingScore
    }

    public func chooseLetter(from context: LetterStrategyContext, using generator: inout SeededRandomGenerator) -> Character? {
        strategy.chooseLetter(from: context, using: &generator)
    }

    /// The game engine is the only component that awards game points.
    public func applyScoreChange(_ points: Int) {
        score += points
    }
}

public struct PlayerScore: Equatable {
    public let playerID: String
    public let playerName: String
    public let score: Int

    public init(playerID: String, playerName: String, score: Int) {
        self.playerID = playerID
        self.playerName = playerName
        self.score = score
    }
}
