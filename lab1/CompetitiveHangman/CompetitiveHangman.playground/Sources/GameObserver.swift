import Foundation

public protocol GameObserver: AnyObject {
    func game(_ game: Game, didEmit event: GameEvent)
}

public struct GameStatistics: Equatable {
    public fileprivate(set) var totalTurns = 0
    public fileprivate(set) var correctAttempts = 0
    public fileprivate(set) var incorrectAttempts = 0
    public fileprivate(set) var completedRounds = 0
    public fileprivate(set) var successfullySolvedWords = 0

    public init() {}
}

/// A concrete observer that aggregates session-wide statistics.
public final class StatisticsObserver: GameObserver {
    public private(set) var statistics = GameStatistics()

    public init() {}

    public func game(_ game: Game, didEmit event: GameEvent) {
        _ = game
        switch event {
        case .turnStarted:
            statistics.totalTurns += 1
        case let .guessResolved(_, _, _, result, _, _, _, _, _, _, _):
            switch result {
            case .correct:
                statistics.correctAttempts += 1
            case .incorrect:
                statistics.incorrectAttempts += 1
            case .repeated, .invalid:
                break
            }
        case let .roundEnded(_, _, result, _):
            statistics.completedRounds += 1
            if result == .solved { statistics.successfullySolvedWords += 1 }
        default:
            break
        }
    }
}

/// Prints the game journal. The engine itself never writes directly to stdout.
public final class ConsoleGameObserver: GameObserver {
    public init() {}

    public func game(_ game: Game, didEmit event: GameEvent) {
        _ = game
        switch event {
        case let .gameStarted(playerNames, rounds):
            print("Started a new game of Competitive Hangman")
            print("Players: \(playerNames.joined(separator: ", "))")
            print("Rounds: \(rounds)")
            print("======")
        case let .roundStarted(round, wordLength, startingPlayer, pattern, mistakeLimit):
            print("\nROUND \(round)")
            print("Secret word: \(pattern) (\(wordLength) letters)")
            print("Starting player: \(startingPlayer)")
            print("Mistakes: 0/\(mistakeLimit)")
        case let .turnStarted(_, playerName):
            print("\n\(playerName)'s turn")
        case let .guessResolved(_, playerName, letter, result, pattern, mistakes, mistakeLimit, drawing, scoreChange, scoreTotal, solveBonus):
            print("\(playerName) guesses: \(letter)")
            switch result {
            case let .correct(revealedCount):
                print("Correct guess! Revealed \(revealedCount) occurrence(s).")
                print("Current word: \(pattern)")
                if solveBonus > 0 {
                    print("\(playerName) earns \(scoreChange - solveBonus) points and a 20 point solve bonus (score: \(scoreTotal))")
                } else {
                    print("\(playerName) earns \(scoreChange) points (score: \(scoreTotal))")
                }
            case .incorrect:
                print("Wrong guess!")
                print("Current word: \(pattern)")
                print("Mistakes: \(mistakes)/\(mistakeLimit)")
                if let drawing { print(drawing) }
                print("\(playerName) loses 5 points (score: \(scoreTotal))")
            case .repeated:
                print("Guess rejected: that letter was already used.")
            case .invalid:
                print("Guess rejected: only letters A-Z are allowed.")
            }
        case let .strategyUnavailable(_, playerName, availableLetterCount):
            if availableLetterCount == 0 {
                print("No letters remain for \(playerName); the round ends safely.")
            } else {
                print("\(playerName)'s strategy returned no guess although \(availableLetterCount) letters remain; the round ends safely.")
            }
        case let .roundEnded(round, solution, result, scores):
            print("\nRound \(round) finished!")
            print("Word: \(solution)")
            print("Round result: \(result)")
            print("Scores: \(scoreLine(scores))")
        case let .gameFinished(scores, winners):
            print("\nGAME OVER")
            print("Final scoreboard:")
            for score in scores {
                print("\(score.playerName): \(score.score)")
            }
            if winners.count == 1, let winner = winners.first {
                print("\nWinner: \(winner)")
            } else {
                print("\nTie between: \(winners.joined(separator: ", "))")
            }
        }
    }

    private func scoreLine(_ scores: [PlayerScore]) -> String {
        scores.map { "\($0.playerName) \($0.score)" }.joined(separator: ", ")
    }
}

/// Stored weakly by Game so subscribing an observer cannot create a retain cycle.
final class WeakGameObserver {
    weak var value: GameObserver?

    init(_ value: GameObserver) {
        self.value = value
    }
}
