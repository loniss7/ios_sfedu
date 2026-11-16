import Foundation

public enum WordGuessResult: Equatable {
    case correct(revealedCount: Int)
    case incorrect
    case repeated
    case invalid

    public var isCorrect: Bool {
        if case .correct = self { return true }
        return false
    }

    public var pointsForRevealedLetters: Int {
        if case let .correct(count) = self { return count * 10 }
        return 0
    }
}

/// Behavior expected from a hidden-word puzzle. No solution getter is exposed here.
public protocol WordGuessing: AnyObject {
    var guessedLetters: Set<Character> { get }
    var displayPattern: String { get }
    var isSolved: Bool { get }
    func submit(_ letter: Character) -> WordGuessResult
}

public enum WordPuzzleError: Error, CustomStringConvertible {
    case invalidWord(String)

    public var description: String {
        switch self {
        case let .invalidWord(word): return "Puzzle word must contain only Latin letters A-Z: \(word)"
        }
    }
}

public final class WordPuzzle: WordGuessing {
    private let secretWord: [Character]
    public private(set) var guessedLetters = Set<Character>()

    public init(word: String) throws {
        let isLatinWord = !word.isEmpty && word.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122)
        }
        guard isLatinWord else {
            throw WordPuzzleError.invalidWord(word)
        }
        let normalized = word.uppercased()
        self.secretWord = Array(normalized)
    }

    public var displayPattern: String {
        secretWord.map { guessedLetters.contains($0) ? String($0) : "_" }.joined(separator: " ")
    }

    public var isSolved: Bool {
        secretWord.allSatisfy { guessedLetters.contains($0) }
    }

    public func submit(_ letter: Character) -> WordGuessResult {
        let normalized = String(letter).uppercased()
        guard normalized.unicodeScalars.count == 1,
              let scalar = normalized.unicodeScalars.first,
              scalar.value >= 65, scalar.value <= 90 else {
            return .invalid
        }

        let normalizedLetter = Character(scalar)
        guard !guessedLetters.contains(normalizedLetter) else { return .repeated }
        guessedLetters.insert(normalizedLetter)
        let matchCount = secretWord.reduce(into: 0) { count, character in
            if character == normalizedLetter { count += 1 }
        }
        return matchCount > 0 ? .correct(revealedCount: matchCount) : .incorrect
    }
}
