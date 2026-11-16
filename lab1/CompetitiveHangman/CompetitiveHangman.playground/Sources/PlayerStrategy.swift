import Foundation

/// Public information available to a letter strategy. The secret word is not part of this value.
public struct LetterStrategyContext {
    public let usedLetters: Set<Character>
    public let visiblePattern: String
    public let remainingAttempts: Int

    public init(usedLetters: Set<Character>, visiblePattern: String, remainingAttempts: Int) {
        self.usedLetters = usedLetters
        self.visiblePattern = visiblePattern
        self.remainingAttempts = remainingAttempts
    }

    public var availableLetters: [Character] {
        (UInt32(65)...UInt32(90)).compactMap { scalarValue in
            guard let scalar = UnicodeScalar(scalarValue) else { return nil }
            let letter = Character(scalar)
            return usedLetters.contains(letter) ? nil : letter
        }
    }
}

/// Implementations choose only from letters that have not already been guessed.
public protocol PlayerStrategy {
    var strategyName: String { get }
    func chooseLetter(from context: LetterStrategyContext, using generator: inout SeededRandomGenerator) -> Character?
}

public struct RandomLetterStrategy: PlayerStrategy {
    public let strategyName = "Random"

    public init() {}

    public func chooseLetter(from context: LetterStrategyContext, using generator: inout SeededRandomGenerator) -> Character? {
        let candidates = context.availableLetters
        guard !candidates.isEmpty else { return nil }
        let index = Int(generator.next() % UInt64(candidates.count))
        return candidates[index]
    }
}

public struct FrequencyLetterStrategy: PlayerStrategy {
    public let strategyName = "English letter frequency"
    private let frequencyOrder = Array("ETAOINSHRDLUCMFWYPVBGKJQXZ")

    public init() {}

    public func chooseLetter(from context: LetterStrategyContext, using generator: inout SeededRandomGenerator) -> Character? {
        _ = generator // This strategy is deterministic; it still shares the strategy protocol.
        return frequencyOrder.first { !context.usedLetters.contains($0) }
    }
}
