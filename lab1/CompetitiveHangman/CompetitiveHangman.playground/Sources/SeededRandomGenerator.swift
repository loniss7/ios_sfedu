import Foundation

/// A small deterministic generator whose output is stable for a given seed.
public struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        // A zero state is valid for this generator, but replacing it makes the
        // sequence less surprising to readers familiar with xorshift RNGs.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        // SplitMix64: compact, reproducible, and sufficient for this game.
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
