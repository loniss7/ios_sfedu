import Foundation
import SwiftUI

final class HangmanViewModel: ObservableObject {
    @Published private(set) var logEntries: [String] = []
    @Published private(set) var scores: [PlayerScore] = []
    @Published private(set) var roundsPlayed = 0
    @Published private(set) var gameFinished = false
    @Published private(set) var isRunning = false

    private var eventObserver: HangmanUIObserver?

    var transcript: String {
        logEntries.joined(separator: "\n\n")
    }

    func startNewGame() {
        guard !isRunning else { return }

        logEntries = []
        scores = []
        roundsPlayed = 0
        gameFinished = false
        isRunning = true

        do {
            let game = try Game(rounds: 5, maximumMistakes: 6, seed: 20261115)
            let observer = HangmanUIObserver { [weak self] event in
                self?.receive(event)
            }
            eventObserver = observer
            game.addObserver(observer)
            try game.run()
            scores = game.scores
        } catch {
            logEntries.append("Не удалось запустить игру: \(error)")
        }

        gameFinished = true
        isRunning = false
    }

    func resetGame() {
        guard !isRunning else { return }
        logEntries = []
        scores = []
        roundsPlayed = 0
        gameFinished = false
        eventObserver = nil
    }

    private func receive(_ event: GameEvent) {
        switch event {
        case let .gameStarted(playerNames, rounds):
            logEntries.append("ПАРТИЯ НАЧАЛАСЬ\nИгроки: \(playerNames.joined(separator: ", "))\nРаундов: \(rounds)")

        case let .roundStarted(round, wordLength, startingPlayer, initialPattern, mistakeLimit):
            logEntries.append("РАУНД \(round)\nСлово: \(initialPattern) (\(wordLength) букв)\nПервым ходит: \(startingPlayer)\nОшибки: 0/\(mistakeLimit)")

        case let .turnStarted(_, playerName):
            logEntries.append("Ход игрока \(playerName)")

        case let .guessResolved(_, playerName, letter, result, pattern, mistakes, mistakeLimit, drawing, scoreChange, scoreTotal, solveBonus):
            var lines = ["\(playerName) называет букву \(letter)"]
            switch result {
            case let .correct(revealedCount):
                lines.append("Верно: открыто букв — \(revealedCount). Слово: \(pattern)")
                if solveBonus > 0 {
                    lines.append("+\(scoreChange - solveBonus) очков и бонус +\(solveBonus). Счёт: \(scoreTotal)")
                } else {
                    lines.append("+\(scoreChange) очков. Счёт: \(scoreTotal)")
                }
            case .incorrect:
                lines.append("Мимо. Слово: \(pattern). Ошибки: \(mistakes)/\(mistakeLimit)")
                if let drawing { lines.append(drawing) }
                lines.append("−5 очков. Счёт: \(scoreTotal)")
            case .repeated:
                lines.append("Эта буква уже использована.")
            case .invalid:
                lines.append("Недопустимая буква.")
            }
            logEntries.append(lines.joined(separator: "\n"))

        case let .strategyUnavailable(_, playerName, _):
            logEntries.append("У игрока \(playerName) закончились доступные буквы.")

        case let .roundEnded(round, solution, result, finalScores):
            roundsPlayed = round
            let scoreLine = finalScores.map { "\($0.playerName): \($0.score)" }.joined(separator: " · ")
            logEntries.append("Раунд \(round) завершён: \(result == .solved ? "слово разгадано" : "попытки закончились") — \(solution)\nСчёт: \(scoreLine)")

        case let .gameFinished(finalScores, winners):
            scores = finalScores
            let result = winners.count == 1
                ? "Победитель: \(winners[0])"
                : "Ничья: \(winners.joined(separator: ", "))"
            logEntries.append("ИГРА ОКОНЧЕНА\n\(result)")
        }
    }
}

private final class HangmanUIObserver: GameObserver {
    private let onEvent: (GameEvent) -> Void

    init(onEvent: @escaping (GameEvent) -> Void) {
        self.onEvent = onEvent
    }

    func game(_ game: Game, didEmit event: GameEvent) {
        _ = game
        onEvent(event)
    }
}
