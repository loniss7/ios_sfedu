import Foundation

public protocol GameDelegate: AnyObject {
    func gameDidStartRound(_ round: Int, wordLength: Int, startingPlayer: String)
    func gameDidEndRound(_ round: Int, solution: String, result: RoundResult)
    func gameDidFinish(scores: [PlayerScore], winners: [String])
}

/// Records lifecycle callbacks separately from the event stream.
public final class GameLifecycleDelegate: GameDelegate {
    public private(set) var startedRounds: [Int] = []
    public private(set) var startingWordLengths: [Int] = []
    public private(set) var startingPlayers: [String] = []
    public private(set) var completedRounds: [(round: Int, solution: String, result: RoundResult)] = []
    public private(set) var finalScores: [PlayerScore] = []
    public private(set) var winners: [String] = []

    public init() {}

    public func gameDidStartRound(_ round: Int, wordLength: Int, startingPlayer: String) {
        startedRounds.append(round)
        startingWordLengths.append(wordLength)
        startingPlayers.append(startingPlayer)
    }

    public func gameDidEndRound(_ round: Int, solution: String, result: RoundResult) {
        completedRounds.append((round: round, solution: solution, result: result))
    }

    public func gameDidFinish(scores: [PlayerScore], winners: [String]) {
        finalScores = scores
        self.winners = winners
    }
}
