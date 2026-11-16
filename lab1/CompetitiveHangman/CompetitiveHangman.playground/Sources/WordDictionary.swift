import Foundation

public enum WordDictionaryError: Error, CustomStringConvertible {
    case emptyDictionary
    case invalidWord(String)

    public var description: String {
        switch self {
        case .emptyDictionary:
            return "The word dictionary must contain at least one word."
        case let .invalidWord(word):
            return "Dictionary word must contain only Latin letters A-Z: \(word)"
        }
    }
}

/// The dictionary is separate from the game engine and validates every entry at construction.
public struct WordDictionary {
    private let words: [String]

    public static let builtIn: WordDictionary = {
        // This list is static project data; initialization below still validates it.
        try! WordDictionary(words: [
            "SWIFT", "OBJECT", "CLASS", "PROTOCOL", "DELEGATE", "OBSERVER",
            "FUNCTION", "VARIABLE", "COMPILER", "ALGORITHM", "DATABASE",
            "NETWORK", "SERVER", "CLIENT", "THREAD", "MEMORY", "PACKAGE",
            "INTERFACE", "FRAMEWORK", "SOFTWARE", "BOOLEAN", "INTEGER",
            "STRUCT", "OPTIONAL", "CLOSURE", "DEBUGGER", "BINARY", "SOURCE"
        ])
    }()

    public init(words: [String]) throws {
        guard !words.isEmpty else { throw WordDictionaryError.emptyDictionary }

        var normalized: [String] = []
        for sourceWord in words {
            let isLatinWord = !sourceWord.isEmpty && sourceWord.unicodeScalars.allSatisfy { scalar in
                (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122)
            }
            guard isLatinWord else { throw WordDictionaryError.invalidWord(sourceWord) }
            normalized.append(sourceWord.uppercased())
        }
        self.words = normalized
    }

    public var count: Int { words.count }

    public func randomWord(using generator: inout SeededRandomGenerator) -> String {
        let index = Int(generator.next() % UInt64(words.count))
        return words[index]
    }
}
