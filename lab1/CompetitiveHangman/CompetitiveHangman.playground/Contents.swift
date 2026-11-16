import Foundation

private final class ScriptedLetterStrategy: PlayerStrategy {
    let strategyName = "Scripted self-check"
    private let letters: [Character]
    private var nextIndex = 0
    private(set) var receivedContexts: [LetterStrategyContext] = []

    init(_ letters: String) {
        self.letters = Array(letters)
    }

    func chooseLetter(from context: LetterStrategyContext, using generator: inout SeededRandomGenerator) -> Character? {
        _ = generator
        receivedContexts.append(context)
        guard nextIndex < letters.count else { return nil }
        defer { nextIndex += 1 }
        return letters[nextIndex]
    }
}

private final class RepeatingLetterStrategy: PlayerStrategy {
    let strategyName = "Repeating self-check"
    private let letter: Character

    init(_ letter: Character) { self.letter = letter }

    func chooseLetter(from context: LetterStrategyContext, using generator: inout SeededRandomGenerator) -> Character? {
        _ = generator
        return context.availableLetters.contains(letter) ? letter : nil
    }
}

private final class RecordingObserver: GameObserver {
    private(set) var events: [GameEvent] = []
    func game(_ game: Game, didEmit event: GameEvent) {
        _ = game
        events.append(event)
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        let failure = "Self-check failed: \(message)"
        ErrorFileLogger.record(message: failure, sourceFile: #filePath)
        fatalError(failure)
    }
}

private func wordsPlayed(in observer: RecordingObserver) -> [String] {
    observer.events.compactMap { event in
        if case let .roundEnded(_, solution, _, _) = event { return solution }
        return nil
    }
}

private func results(in observer: RecordingObserver) -> [RoundResult] {
    observer.events.compactMap { event in
        if case let .roundEnded(_, _, result, _) = event { return result }
        return nil
    }
}

private func turnNames(in observer: RecordingObserver) -> [String] {
    observer.events.compactMap { event in
        if case let .turnStarted(_, playerName) = event { return playerName }
        return nil
    }
}

private func runSelfChecks() throws {
    print("Running built-in business-logic checks...")

    let lowerCaseDictionary = try WordDictionary(words: ["swift"])
    var dictionaryRandom = SeededRandomGenerator(seed: 10)
    require(lowerCaseDictionary.randomWord(using: &dictionaryRandom) == "SWIFT", "dictionary normalizes words to uppercase")
    require(WordDictionary.builtIn.count >= 20, "built-in dictionary has at least 20 words")
    var invalidDictionaryWasRejected = false
    do {
        _ = try WordDictionary(words: ["NOT VALID"])
    } catch {
        invalidDictionaryWasRejected = true
    }
    require(invalidDictionaryWasRejected, "dictionary rejects non-letter input")

    // Correct guesses reveal every occurrence; a duplicate leaves the puzzle unchanged.
    let duplicatePuzzle = try WordPuzzle(word: "LEVEL")
    let firstL = duplicatePuzzle.submit("L")
    require(firstL == .correct(revealedCount: 2), "correct letter reveals all matching positions")
    require(duplicatePuzzle.displayPattern == "L _ _ _ L", "pattern displays all occurrences")
    require(duplicatePuzzle.submit("L") == .repeated, "repeated letter is rejected")
    require(duplicatePuzzle.guessedLetters == ["L"], "repeated letter does not alter guessed letters")

    let drawing = HangmanDrawing(maximumMistakes: 6)
    require(drawing.recordMistake() == 1 && drawing.asciiArt.contains("O"), "first mistake advances the drawing")
    for _ in 2...6 { drawing.recordMistake() }
    require(drawing.mistakes == 6 && drawing.isAtLimit, "drawing counts up to the configured limit")
    let cappedMistakes = drawing.recordMistake()
    require(cappedMistakes == 6, "drawing cannot exceed its mistake limit")
    require(drawing.asciiArt.contains("/ \\"), "six mistakes show the complete drawing")

    let strategyContext = LetterStrategyContext(usedLetters: ["E", "T"], visiblePattern: "_ _ _", remainingAttempts: 4)
    var strategyGenerator = SeededRandomGenerator(seed: 20)
    let frequencyChoice = FrequencyLetterStrategy().chooseLetter(from: strategyContext, using: &strategyGenerator)
    require(frequencyChoice == "A", "frequency strategy follows English letter frequency and skips used letters")
    let randomChoice = RandomLetterStrategy().chooseLetter(from: strategyContext, using: &strategyGenerator)
    require(randomChoice.map { strategyContext.availableLetters.contains($0) } == true, "random strategy selects an available letter")
    let exhaustedContext = LetterStrategyContext(usedLetters: Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), visiblePattern: "_", remainingAttempts: 0)
    require(RandomLetterStrategy().chooseLetter(from: exhaustedContext, using: &strategyGenerator) == nil, "strategy handles an exhausted alphabet")

    // One deterministic round covers point values, wrong-guess penalty, turns, observers, and delegate callbacks.
    let scoringWord = try WordDictionary(words: ["ABA"])
    let banana = try WordDictionary(words: ["BANANA"])
    let Alice = Player(id: "check-alice", name: "Alice", strategy: ScriptedLetterStrategy("AB"))
    let Bob = Player(id: "check-bob", name: "Bob", strategy: ScriptedLetterStrategy("Z"))
    let scoringGame = try Game(players: [Alice, Bob], rounds: 1, dictionary: scoringWord, seed: 11)
    let scoringRecorder = RecordingObserver()
    let scoringStatistics = StatisticsObserver()
    let scoringDelegate = GameLifecycleDelegate()
    scoringGame.addObserver(scoringRecorder)
    scoringGame.addObserver(scoringStatistics)
    scoringGame.delegate = scoringDelegate
    try scoringGame.run()

    require(turnNames(in: scoringRecorder) == ["Alice", "Bob", "Alice"], "turn order advances to the next player")
    require(Alice.score == 50 && Bob.score == -5, "scores include 10 per revealed letter, a 20 point solve bonus, and a 5 point penalty")
    require(results(in: scoringRecorder) == [.solved], "a fully revealed word ends the round successfully")
    require(scoringStatistics.statistics.totalTurns == 3, "statistics observer counts turns")
    require(scoringStatistics.statistics.correctAttempts == 2 && scoringStatistics.statistics.incorrectAttempts == 1, "statistics observer counts guess outcomes")
    require(scoringStatistics.statistics.completedRounds == 1 && scoringStatistics.statistics.successfullySolvedWords == 1, "statistics observer counts round outcomes")
    let delegateStartedExpectedRound = scoringDelegate.startedRounds == [1]
        && scoringDelegate.startingWordLengths == [3]
        && scoringDelegate.startingPlayers == ["Alice"]
    let delegateCompletedExpectedRound = scoringDelegate.completedRounds.first?.solution == "ABA"
    require(delegateStartedExpectedRound && delegateCompletedExpectedRound, "delegate receives round lifecycle callbacks")
    require(scoringDelegate.winners == ["Alice"], "delegate receives the final winner")
    let firstWrongDrawing = scoringRecorder.events.contains { event in
        if case let .guessResolved(_, _, _, result, _, mistakes, _, art, scoreChange, _, _) = event {
            return result == .incorrect && mistakes == 1 && art?.contains("O") == true && scoreChange == -5
        }
        return false
    }
    require(firstWrongDrawing, "wrong guess increments mistakes and publishes the matching ASCII drawing")

    // Strategies receive only the public pattern and already used letters.
    let aliceStrategyContexts = (Alice.strategy as? ScriptedLetterStrategy)?.receivedContexts ?? []
    require(!aliceStrategyContexts.isEmpty, "strategy receives a public information context")
    let contextLabels = Mirror(reflecting: aliceStrategyContexts[0]).children.compactMap(\.label)
    require(contextLabels.contains("visiblePattern") && !contextLabels.contains("secretWord"), "strategy context has no hidden solution field")
    require(aliceStrategyContexts[1].visiblePattern == "A _ A", "strategy sees the current revealed pattern")

    // Six wrong letters end the round and each player receives the correct penalty.
    let losingGame = try Game(
        players: [
            Player(id: "lose-a", name: "A", strategy: ScriptedLetterStrategy("QXJ")),
            Player(id: "lose-b", name: "B", strategy: ScriptedLetterStrategy("ZKV"))
        ],
        rounds: 1,
        dictionary: banana,
        seed: 12
    )
    let losingRecorder = RecordingObserver()
    let losingDelegate = GameLifecycleDelegate()
    losingGame.addObserver(losingRecorder)
    losingGame.delegate = losingDelegate
    try losingGame.run()
    require(results(in: losingRecorder) == [.lost], "six wrong guesses end a round in a loss")
    require(losingGame.players.map(\.score) == [-15, -15], "negative points are permitted and penalties are applied")
    let mistakeCounts = losingRecorder.events.compactMap { event -> Int? in
        if case let .guessResolved(_, _, _, result, _, mistakes, _, _, _, _, _) = event, result == .incorrect {
            return mistakes
        }
        return nil
    }
    require(mistakeCounts == [1, 2, 3, 4, 5, 6], "mistake count advances exactly once per wrong letter")
    require(losingDelegate.completedRounds.first?.result == .lost, "delegate receives a failed round")

    // Five rounds rotate the starting player and determine the leader from total score.
    let oneLetter = try WordDictionary(words: ["A"])
    let fiveRoundGame = try Game(
        players: [
            Player(id: "five-alice", name: "Alice", strategy: RepeatingLetterStrategy("A")),
            Player(id: "five-bob", name: "Bob", strategy: RepeatingLetterStrategy("A"))
        ],
        rounds: 5,
        dictionary: oneLetter,
        seed: 13
    )
    let fiveRoundRecorder = RecordingObserver()
    fiveRoundGame.addObserver(fiveRoundRecorder)
    try fiveRoundGame.run()
    require(fiveRoundGame.roundsPlayed == 5 && fiveRoundGame.state == .finished, "the configured five-round game reaches finished")
    require(turnNames(in: fiveRoundRecorder) == ["Alice", "Bob", "Alice", "Bob", "Alice"], "starting player alternates by round")
    require(fiveRoundGame.scores.map(\.score) == [90, 60], "round scores accumulate across the session")
    let winners = fiveRoundRecorder.events.compactMap { event -> [String]? in
        if case let .gameFinished(_, winners) = event { return winners }
        return nil
    }.last
    require(winners == ["Alice"], "highest total score wins")

    // A strategy that stops early cannot trap the automatic game in an endless loop.
    let exhaustedGame = try Game(
        players: [
            Player(id: "empty-a", name: "Alice", strategy: ScriptedLetterStrategy("")),
            Player(id: "empty-b", name: "Bob", strategy: ScriptedLetterStrategy(""))
        ],
        rounds: 1,
        dictionary: oneLetter,
        seed: 16
    )
    let exhaustedRecorder = RecordingObserver()
    exhaustedGame.addObserver(exhaustedRecorder)
    try exhaustedGame.run()
    require(results(in: exhaustedRecorder) == [.strategyFailure] && exhaustedGame.state == .finished, "a strategy with no choice ends safely")

    // Identical seeds reproduce word selection and the full sequence of random decisions.
    let reproducibleDictionary = try WordDictionary(words: ["BANANA", "SWIFT", "OBJECT"])
    func makeSeededLossGame() throws -> (Game, RecordingObserver) {
        let game = try Game(
            players: [
                Player(id: "seed-a", name: "Alice", strategy: RepeatingLetterStrategy("Q")),
                Player(id: "seed-b", name: "Bob", strategy: RepeatingLetterStrategy("Q"))
            ],
            rounds: 3,
            dictionary: reproducibleDictionary,
            maximumMistakes: 1,
            seed: 4242
        )
        let recorder = RecordingObserver()
        game.addObserver(recorder)
        return (game, recorder)
    }
    let seededRunOne = try makeSeededLossGame()
    let seededRunTwo = try makeSeededLossGame()
    try seededRunOne.0.run()
    try seededRunTwo.0.run()
    require(wordsPlayed(in: seededRunOne.1) == wordsPlayed(in: seededRunTwo.1), "fixed seed reproduces selected round words")

    // Equal totals result in a tie among all leaders.
    let tiedGame = try Game(
        players: [
            Player(id: "tie-alice", name: "Alice", strategy: RepeatingLetterStrategy("A")),
            Player(id: "tie-bob", name: "Bob", strategy: RepeatingLetterStrategy("A"))
        ],
        rounds: 2,
        dictionary: oneLetter,
        seed: 14
    )
    let tiedRecorder = RecordingObserver()
    tiedGame.addObserver(tiedRecorder)
    try tiedGame.run()
    let tiedWinners = tiedRecorder.events.compactMap { event -> [String]? in
        if case let .gameFinished(_, winners) = event { return winners }
        return nil
    }.last
    require(tiedWinners == ["Alice", "Bob"], "equal top scores are reported as a tie")

    require(GameState.idle.allowsTransition(to: .startingRound(round: 1)), "FSM accepts its initial edge")
    require(!GameState.idle.allowsTransition(to: .finished), "FSM rejects a forbidden edge")
    require(!GameState.waitingForGuess(round: 1, playerIndex: 0).allowsTransition(to: .waitingForGuess(round: 1, playerIndex: 1)), "FSM requires a guess before advancing a turn")

    // Subscription removal is supported and prevents subsequent event delivery.
    let detachedObserver = StatisticsObserver()
    let detachGame = try Game(
        players: [
            Player(id: "detach-a", name: "Alice", strategy: RepeatingLetterStrategy("A")),
            Player(id: "detach-b", name: "Bob", strategy: RepeatingLetterStrategy("A"))
        ],
        rounds: 1,
        dictionary: oneLetter,
        seed: 15
    )
    detachGame.addObserver(detachedObserver)
    detachGame.removeObserver(detachedObserver)
    try detachGame.run()
    require(detachedObserver.statistics == GameStatistics(), "unsubscribed observers no longer receive events")

    print("Self-checks passed: dictionary, puzzle, repeat rejection, scoring, turns, six-error loss, drawing, five-round finish, winner, tie, FSM, Observer, Delegate, subscription removal, and strategy information boundaries.")
}

do {
    try runSelfChecks()

    let game = try Game(seed: 20261115)
    let console = ConsoleGameObserver()
    let statistics = StatisticsObserver()
    let lifecycleDelegate = GameLifecycleDelegate()
    game.addObserver(console)
    game.addObserver(statistics)
    game.delegate = lifecycleDelegate
    try game.run()

    print("\nObserver statistics:")
    print("Turns: \(statistics.statistics.totalTurns)")
    print("Correct attempts: \(statistics.statistics.correctAttempts)")
    print("Wrong attempts: \(statistics.statistics.incorrectAttempts)")
    print("Completed rounds: \(statistics.statistics.completedRounds)")
    print("Solved words: \(statistics.statistics.successfullySolvedWords)")
    print("Lifecycle delegate recorded \(lifecycleDelegate.startedRounds.count) round starts and \(lifecycleDelegate.completedRounds.count) round completions.")
} catch {
    ErrorFileLogger.record(error, sourceFile: #filePath)
    fatalError("Competitive Hangman failed: \(error)")
}
