import Foundation

public final class HangmanDrawing {
    public let maximumMistakes: Int
    public private(set) var mistakes = 0

    public init(maximumMistakes: Int = 6) {
        precondition(maximumMistakes > 0, "Maximum mistakes must be positive.")
        self.maximumMistakes = maximumMistakes
    }

    public var isAtLimit: Bool { mistakes >= maximumMistakes }

    @discardableResult
    public func recordMistake() -> Int {
        if mistakes < maximumMistakes { mistakes += 1 }
        return mistakes
    }

    public var asciiArt: String {
        let stages = [
            ["     |", "     |", "     |", "     |"],
            [" O   |", "     |", "     |", "     |"],
            [" O   |", " |   |", "     |", "     |"],
            [" O   |", "/|   |", "     |", "     |"],
            [" O   |", "/|\\  |", "     |", "     |"],
            [" O   |", "/|\\  |", "/    |", "     |"],
            [" O   |", "/|\\  |", "/ \\  |", "     |"]
        ]

        let stageIndex = min(mistakes, stages.count - 1)
        let body = stages[stageIndex]
        return ([" +---+", " |   |"] + body + ["======="]).joined(separator: "\n")
    }
}
