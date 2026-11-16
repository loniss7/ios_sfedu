import Foundation

/// Coordinates the Competitive Hangman session and owns its finite-state machine.
public final class Game {
    public private(set) var state: GameState = .idle
    public private(set) var roundsPlayed = 0
    public let roundsToPlay: Int
    public let players: [Player]
    public let maximumMistakes: Int
    public weak var delegate: GameDelegate?

    private let dictionary: WordDictionary
    private let rules: [GameRule]
    private var randomGenerator: SeededRandomGenerator
    private var observers: [WeakGameObserver] = []

    public var scores: [PlayerScore] {
        players.map { PlayerScore(playerID: $0.id, playerName: $0.name, score: $0.score) }
    }

    public static func defaultPlayers() -> [Player] {
        [
            Player(id: "alice", name: "Alice", strategy: FrequencyLetterStrategy()),
            Player(id: "bob", name: "Bob", strategy: RandomLetterStrategy())
        ]
    }

    public init(
        players: [Player]? = nil,
        rounds: Int = 5,
        dictionary: WordDictionary = .builtIn,
        maximumMistakes: Int = 6,
        seed: UInt64 = 20261115,
        rules: [GameRule]? = nil
    ) throws {
        let actualPlayers = players ?? Game.defaultPlayers()
        guard (2...4).contains(actualPlayers.count) else {
            throw GameError.invalidConfiguration("Choose between two and four players.")
        }
        guard rounds > 0 else {
            throw GameError.invalidConfiguration("The game must have at least one round.")
        }
        guard maximumMistakes > 0 else {
            throw GameError.invalidConfiguration("Maximum mistakes must be positive.")
        }
        guard actualPlayers.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw GameError.invalidConfiguration("Every player must have a non-empty name.")
        }
        guard Set(actualPlayers.map(\.id)).count == actualPlayers.count else {
            throw GameError.invalidConfiguration("Player identifiers must be unique.")
        }
        if let configuredRules = rules, configuredRules.isEmpty {
            throw GameError.invalidConfiguration("At least one round-ending rule is required.")
        }

        self.players = actualPlayers
        self.roundsToPlay = rounds
        self.dictionary = dictionary
        self.maximumMistakes = maximumMistakes
        self.randomGenerator = SeededRandomGenerator(seed: seed)
        if let configuredRules = rules {
            self.rules = configuredRules
        } else {
            self.rules = [WordSolvedRule(), MaximumMistakesRule()]
        }
    }

    /// Subscribe an observer. The game keeps a weak reference; callers own observer lifetime.
    public func addObserver(_ observer: GameObserver) {
        observers.removeAll { entry in
            guard let current = entry.value else { return true }
            return current === observer
        }
        observers.append(WeakGameObserver(observer))
    }

    public func removeObserver(_ observer: GameObserver) {
        observers.removeAll { entry in
            guard let current = entry.value else { return true }
            return current === observer
        }
    }

    /// Runs the complete automatic session. A Game instance is single-use.
    public func run() throws {
        guard state == .idle else { throw GameError.gameAlreadyStarted }

        emit(.gameStarted(playerNames: players.map(\.name), rounds: roundsToPlay))
        var roundNumber = 1

        while roundNumber <= roundsToPlay {
            try transition(to: .startingRound(round: roundNumber))

            let solution = dictionary.randomWord(using: &randomGenerator)
            let puzzle: WordGuessing = try WordPuzzle(word: solution)
            let drawing = HangmanDrawing(maximumMistakes: maximumMistakes)
            let startingPlayerIndex = (roundNumber - 1) % players.count
            let startingPlayer = players[startingPlayerIndex]

            emit(.roundStarted(
                round: roundNumber,
                wordLength: solution.count,
                startingPlayer: startingPlayer.name,
                initialPattern: puzzle.displayPattern,
                mistakeLimit: maximumMistakes
            ))
            delegate?.gameDidStartRound(roundNumber, wordLength: solution.count, startingPlayer: startingPlayer.name)

            try transition(to: .waitingForGuess(round: roundNumber, playerIndex: startingPlayerIndex))
            var roundResult: RoundResult?

            while roundResult == nil {
                guard case let .waitingForGuess(activeRound, playerIndex) = state,
                      activeRound == roundNumber,
                      players.indices.contains(playerIndex) else {
                    throw GameError.invalidTransition(from: state, to: .waitingForGuess(round: roundNumber, playerIndex: startingPlayerIndex))
                }

                let player = players[playerIndex]
                emit(.turnStarted(round: roundNumber, playerName: player.name))
                let context = LetterStrategyContext(
                    usedLetters: puzzle.guessedLetters,
                    visiblePattern: puzzle.displayPattern,
                    remainingAttempts: maximumMistakes - drawing.mistakes
                )

                guard let selectedLetter = player.chooseLetter(from: context, using: &randomGenerator) else {
                    emit(.strategyUnavailable(
                        round: roundNumber,
                        playerName: player.name,
                        availableLetterCount: context.availableLetters.count
                    ))
                    let result: RoundResult = context.availableLetters.isEmpty ? .noAvailableLetters : .strategyFailure
                    roundResult = result
                    try transition(to: .endingRound(round: roundNumber, result: result))
                    break
                }

                let letter = Self.normalizedLetter(selectedLetter) ?? selectedLetter
                try transition(to: .evaluatingGuess(round: roundNumber, playerIndex: playerIndex, letter: letter))
                let guessResult: WordGuessResult
                if Self.normalizedLetter(selectedLetter) == nil {
                    guessResult = .invalid
                } else {
                    guessResult = puzzle.submit(letter)
                }

                var scoreChange = 0
                var solveBonus = 0
                var drawingForEvent: String?

                switch guessResult {
                case .correct:
                    scoreChange = guessResult.pointsForRevealedLetters
                    if puzzle.isSolved {
                        solveBonus = 20
                        scoreChange += solveBonus
                    }
                case .incorrect:
                    drawing.recordMistake()
                    scoreChange = -5
                    drawingForEvent = drawing.asciiArt
                case .repeated, .invalid:
                    break
                }

                if scoreChange != 0 { player.applyScoreChange(scoreChange) }
                emit(.guessResolved(
                    round: roundNumber,
                    playerName: player.name,
                    letter: letter,
                    result: guessResult,
                    pattern: puzzle.displayPattern,
                    mistakes: drawing.mistakes,
                    mistakeLimit: drawing.maximumMistakes,
                    drawing: drawingForEvent,
                    scoreChange: scoreChange,
                    scoreTotal: player.score,
                    solveBonus: solveBonus
                ))

                let nextPlayerIndex = (playerIndex + 1) % players.count
                try transition(to: .endingTurn(round: roundNumber, nextPlayerIndex: nextPlayerIndex))

                let outcome = (guessResult == .repeated || guessResult == .invalid)
                    ? RoundResult.strategyFailure
                    : rules.compactMap { $0.outcome(for: puzzle, drawing: drawing) }.first

                if let outcome {
                    roundResult = outcome
                    try transition(to: .endingRound(round: roundNumber, result: outcome))
                } else {
                    try transition(to: .waitingForGuess(round: roundNumber, playerIndex: nextPlayerIndex))
                }
            }

            guard let completedResult = roundResult else {
                throw GameError.invalidTransition(from: state, to: .endingRound(round: roundNumber, result: .strategyFailure))
            }

            let completedSolution = solution
            emit(.roundEnded(round: roundNumber, solution: completedSolution, result: completedResult, scores: scores))
            delegate?.gameDidEndRound(roundNumber, solution: completedSolution, result: completedResult)
            roundsPlayed += 1

            if roundNumber < roundsToPlay {
                roundNumber += 1
            } else {
                try transition(to: .finished)
            }
        }

        let finalScores = scores
        let topScore = finalScores.map(\.score).max() ?? 0
        let winners = finalScores.filter { $0.score == topScore }.map(\.playerName)
        emit(.gameFinished(scores: finalScores, winners: winners))
        delegate?.gameDidFinish(scores: finalScores, winners: winners)
    }

    private func transition(to next: GameState) throws {
        guard state.allowsTransition(to: next) else {
            throw GameError.invalidTransition(from: state, to: next)
        }
        state = next
    }

    private func emit(_ event: GameEvent) {
        observers.removeAll { entry in
            if case nil = entry.value { return true }
            return false
        }
        let currentObservers = observers.compactMap(\.value)
        for observer in currentObservers {
            observer.game(self, didEmit: event)
        }
    }

    private static func normalizedLetter(_ letter: Character) -> Character? {
        let normalized = String(letter).uppercased()
        guard normalized.unicodeScalars.count == 1,
              let scalar = normalized.unicodeScalars.first,
              scalar.value >= 65,
              scalar.value <= 90 else { return nil }
        return Character(scalar)
    }
}
