import Foundation

public enum RoundResult: String, Equatable, CustomStringConvertible {
    case solved
    case lost
    case noAvailableLetters
    case strategyFailure

    public var description: String {
        switch self {
        case .solved: return "Solved"
        case .lost: return "Lost"
        case .noAvailableLetters: return "No available letters"
        case .strategyFailure: return "Strategy failure"
        }
    }
}

/// The game flow is represented by one state value, rather than a set of flags.
public enum GameState: Equatable, CustomStringConvertible {
    case idle
    case startingRound(round: Int)
    case waitingForGuess(round: Int, playerIndex: Int)
    case evaluatingGuess(round: Int, playerIndex: Int, letter: Character)
    case endingTurn(round: Int, nextPlayerIndex: Int)
    case endingRound(round: Int, result: RoundResult)
    case finished

    public var description: String {
        switch self {
        case .idle:
            return "idle"
        case let .startingRound(round):
            return "startingRound(\(round))"
        case let .waitingForGuess(round, playerIndex):
            return "waitingForGuess(round: \(round), playerIndex: \(playerIndex))"
        case let .evaluatingGuess(round, playerIndex, letter):
            return "evaluatingGuess(round: \(round), playerIndex: \(playerIndex), letter: \(letter))"
        case let .endingTurn(round, nextPlayerIndex):
            return "endingTurn(round: \(round), nextPlayerIndex: \(nextPlayerIndex))"
        case let .endingRound(round, result):
            return "endingRound(round: \(round), result: \(result))"
        case .finished:
            return "finished"
        }
    }

    /// Returns whether the requested edge exists in the game's FSM.
    public func allowsTransition(to next: GameState) -> Bool {
        switch self {
        case .idle:
            if case .startingRound(round: 1) = next { return true }
            return false
        case let .startingRound(round):
            if case let .waitingForGuess(nextRound, _) = next { return nextRound == round }
            return false
        case let .waitingForGuess(round, playerIndex):
            switch next {
            case let .evaluatingGuess(nextRound, nextPlayerIndex, _):
                return nextRound == round && nextPlayerIndex == playerIndex
            case let .endingRound(nextRound, _):
                // The direct ending edge is reserved for a strategy with no legal move.
                return nextRound == round
            default:
                return false
            }
        case let .evaluatingGuess(round, playerIndex, _):
            if case let .endingTurn(nextRound, nextPlayerIndex) = next {
                return nextRound == round && playerIndex >= 0 && nextPlayerIndex >= 0 && nextPlayerIndex != playerIndex
            }
            return false
        case let .endingTurn(round, expectedNextPlayerIndex):
            switch next {
            case let .waitingForGuess(nextRound, nextPlayerIndex):
                return nextRound == round && nextPlayerIndex == expectedNextPlayerIndex
            case let .endingRound(nextRound, _):
                return nextRound == round
            default:
                return false
            }
        case let .endingRound(round, _):
            switch next {
            case let .startingRound(nextRound):
                return nextRound == round + 1
            case .finished:
                return true
            default:
                return false
            }
        case .finished:
            return false
        }
    }
}

public enum GameError: Error, CustomStringConvertible {
    case invalidTransition(from: GameState, to: GameState)
    case invalidConfiguration(String)
    case gameAlreadyStarted

    public var description: String {
        switch self {
        case let .invalidTransition(from, to):
            return "Illegal FSM transition: \(from) -> \(to)"
        case let .invalidConfiguration(message):
            return "Invalid game configuration: \(message)"
        case .gameAlreadyStarted:
            return "A Game instance can only be run once."
        }
    }
}
