import Foundation

/// A stateful calculator model. The UI observes its changes through `delegate`.
public final class CalculatorModel: Calculator {

    public weak var delegate: CalculatorDelegate?

    public private(set) var result: Double?
    public private(set) var operation: Operation?

    /// The current right-hand operand. A separate string is kept so that the
    /// model can preserve a trailing decimal point and zeroes after the point.
    public var input: Double? {
        guard let inputText = inputText else { return nil }
        return Double(inputText)
    }

    public var hasPoint: Bool {
        return inputText?.contains(".") ?? false
    }

    public var fractionDigits: UInt {
        guard let inputText = inputText,
              let separatorIndex = inputText.firstIndex(of: ".") else { return 0 }
        let count = inputText[inputText.index(after: separatorIndex)...].count
        return UInt(count)
    }

    private let maximumInputLength: Int
    private let maximumFractionDigits: Int
    private var inputText: String?
    private var resultFractionDigits: UInt = 0

    public required init(inputLength len: UInt, maxFraction frac: UInt) {
        maximumInputLength = Int(exactly: len) ?? Int.max
        maximumFractionDigits = Int(exactly: frac) ?? Int.max
    }

    public func addDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }

        let startsNewEntry = inputText == nil && operation == nil
        let current = inputText ?? "0"

        var candidate = current

        if candidate.contains(".") {
            guard Int(fractionDigits) < maximumFractionDigits else {
                notifyInputOverflow()
                return
            }
            candidate.append(String(digit))
        } else {
            let isNegative = candidate.hasPrefix("-")
            let integerPart = isNegative ? String(candidate.dropFirst()) : candidate

            if integerPart == "0" {
                if digit == 0 {
                    // Keep the first zero, but ignore repeated leading zeroes.
                    if inputText != nil { return }
                } else {
                    candidate = (isNegative ? "-" : "") + String(digit)
                }
            } else {
                candidate.append(String(digit))
            }
        }

        guard storeInput(candidate) else { return }
        if startsNewEntry {
            result = nil
            resultFractionDigits = 0
        }
        notifyInputValue()
    }

    public func addPoint() {
        if let current = inputText, current.contains(".") { return }

        let startsNewEntry = inputText == nil && operation == nil
        var candidate = inputText ?? "0"
        candidate.append(".")

        guard storeInput(candidate) else { return }
        if startsNewEntry {
            result = nil
            resultFractionDigits = 0
        }
        notifyInputValue()
    }

    public func addOperation(_ newOperation: Operation) {
        switch newOperation {
        case .sign:
            toggleSign()
            return
        case .perc:
            applyPercent()
            return
        case .add, .sub, .mul, .div:
            break
        }

        if operation != nil {
            if input != nil {
                guard evaluateCurrentExpression() else { return }
                operation = newOperation
                notifyResultValue()
            } else {
                // Repeated operator presses replace the pending operation.
                operation = newOperation
            }
            return
        }

        if let inputValue = input {
            result = inputValue
            resultFractionDigits = fractionDigits
            inputText = nil
            operation = newOperation
            notifyResultValue()
        } else if result != nil {
            operation = newOperation
        }
    }

    public func compute() {
        guard evaluateCurrentExpression() else { return }
        notifyResultValue()
    }

    public func clear() {
        inputText = nil
        delegate?.calculatorDidClear(self,
                                     withDefaultValue: result,
                                     defaultPrecision: result == nil ? nil : resultFractionDigits)
    }

    public func reset() {
        inputText = nil
        result = nil
        resultFractionDigits = 0
        operation = nil
        delegate?.calculatorDidClear(self, withDefaultValue: nil, defaultPrecision: nil)
    }

    // MARK: - Operations

    private func toggleSign() {
        if let current = inputText {
            let candidate: String
            if current.hasPrefix("-") {
                candidate = String(current.dropFirst())
            } else {
                candidate = "-" + current
            }
            guard storeInput(candidate) else { return }
            notifyInputValue()
            return
        }

        if operation != nil {
            guard storeInput("-0") else { return }
            notifyInputValue()
        } else if let currentResult = result {
            result = -currentResult
            notifyResultValue()
        } else {
            guard storeInput("-0") else { return }
            notifyInputValue()
        }
    }

    private func applyPercent() {
        if let currentInput = input {
            let candidate = formatInput(currentInput / 100)
            guard storeInput(candidate) else { return }
            notifyInputValue()
        } else if operation == nil, let currentResult = result {
            result = currentResult / 100
            resultFractionDigits = min(UInt(maximumFractionDigits), resultFractionDigits + 2)
            notifyResultValue()
        }
    }

    /// Computes the pending binary expression and updates the model state.
    /// Returns false when there is no complete expression or calculation fails.
    @discardableResult
    private func evaluateCurrentExpression() -> Bool {
        guard let currentOperation = operation,
              let left = result,
              let right = input else { return false }

        let value: Double
        switch currentOperation {
        case .add:
            value = left + right
        case .sub:
            value = left - right
        case .mul:
            value = left * right
        case .div:
            guard right != 0 else {
                delegate?.calculatorDidNotCompute(self, withError: "Делить на ноль нельзя")
                return false
            }
            value = left / right
        case .sign, .perc:
            return false
        }

        guard value.isFinite else {
            delegate?.calculatorDidNotCompute(self, withError: "Результат вычисления слишком велик")
            return false
        }

        let rightFractionDigits = fractionDigits
        switch currentOperation {
        case .add, .sub:
            resultFractionDigits = max(resultFractionDigits, rightFractionDigits)
        case .mul:
            resultFractionDigits = min(UInt(maximumFractionDigits), resultFractionDigits + rightFractionDigits)
        case .div:
            resultFractionDigits = max(resultFractionDigits, rightFractionDigits)
        case .sign, .perc:
            break
        }

        result = value
        operation = nil
        inputText = nil
        return true
    }

    // MARK: - Input and delegate helpers

    /// Stores a candidate only if it fits both configured input limits.
    @discardableResult
    private func storeInput(_ candidate: String) -> Bool {
        let candidateFractionDigits: Int
        if let pointIndex = candidate.firstIndex(of: ".") {
            candidateFractionDigits = candidate[candidate.index(after: pointIndex)...].count
        } else {
            candidateFractionDigits = 0
        }

        guard candidate.count <= maximumInputLength,
              candidateFractionDigits <= maximumFractionDigits,
              let value = Double(candidate), value.isFinite else {
            notifyInputOverflow()
            return false
        }

        inputText = candidate
        return true
    }

    private func notifyInputValue() {
        guard let value = input else { return }
        delegate?.calculatorDidUpdateValue(self, with: value, valuePrecision: fractionDigits)
    }

    private func notifyResultValue() {
        guard let value = result else { return }
        delegate?.calculatorDidUpdateValue(self, with: value, valuePrecision: resultFractionDigits)
    }

    private func notifyInputOverflow() {
        delegate?.calculatorDidInputOverflow(self)
    }

    private func formatInput(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
