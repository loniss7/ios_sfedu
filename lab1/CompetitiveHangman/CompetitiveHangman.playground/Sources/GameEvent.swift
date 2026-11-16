import Foundation

/// Events are the engine's public output channel for logging and statistics.
public enum GameEvent {
    case gameStarted(playerNames: [String], rounds: Int)
    case roundStarted(round: Int, wordLength: Int, startingPlayer: String, initialPattern: String, mistakeLimit: Int)
    case turnStarted(round: Int, playerName: String)
    case guessResolved(
        round: Int,
        playerName: String,
        letter: Character,
        result: WordGuessResult,
        pattern: String,
        mistakes: Int,
        mistakeLimit: Int,
        drawing: String?,
        scoreChange: Int,
        scoreTotal: Int,
        solveBonus: Int
    )
    case strategyUnavailable(round: Int, playerName: String, availableLetterCount: Int)
    case roundEnded(round: Int, solution: String, result: RoundResult, scores: [PlayerScore])
    case gameFinished(scores: [PlayerScore], winners: [String])
}
