import Foundation

public struct ScribeProbeAnswerSelection: Codable, Equatable, Sendable {
    public var questionID: String
    public var selectedOptionID: String
    public var customText: String?

    public init(
        questionID: String,
        selectedOptionID: String,
        customText: String? = nil
    ) {
        self.questionID = questionID
        self.selectedOptionID = selectedOptionID
        self.customText = customText
    }
}

public struct ScribeProbeAnswerBatchDraft: Codable, Equatable, Sendable {
    public private(set) var selectionsByQuestionID: [String: ScribeProbeAnswerSelection]

    public init(selections: [ScribeProbeAnswerSelection] = []) {
        var selectionsByQuestionID: [String: ScribeProbeAnswerSelection] = [:]
        for selection in selections {
            selectionsByQuestionID[selection.questionID] = selection
        }
        self.selectionsByQuestionID = selectionsByQuestionID
    }

    public func selection(for questionID: String) -> ScribeProbeAnswerSelection? {
        selectionsByQuestionID[questionID]
    }

    public mutating func select(
        question: ScribeQuestion,
        option: ScribeProbeOption,
        customText: String? = nil
    ) {
        selectionsByQuestionID[question.id] = ScribeProbeAnswerSelection(
            questionID: question.id,
            selectedOptionID: option.id,
            customText: option.isCustomAnswer ? customText : nil
        )
    }

    public func canSubmit(questions: [ScribeQuestion]) -> Bool {
        missingQuestionIDs(in: questions).isEmpty
    }

    public func missingQuestionIDs(in questions: [ScribeQuestion]) -> [String] {
        questions.compactMap { question in
            answer(for: question) == nil ? question.id : nil
        }
    }

    public func answers(for questions: [ScribeQuestion]) -> [ScribeAnswer] {
        questions.compactMap(answer(for:))
    }

    private func answer(for question: ScribeQuestion) -> ScribeAnswer? {
        guard let selection = selectionsByQuestionID[question.id],
              let option = question.options.first(where: { $0.id == selection.selectedOptionID }) else {
            return nil
        }

        let freeText: String?
        if option.isCustomAnswer {
            guard let normalized = selection.customText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !normalized.isEmpty else {
                return nil
            }
            freeText = normalized
        } else {
            freeText = nil
        }

        return ScribeAnswer(
            questionID: question.id,
            selectedOptionID: option.id,
            selectedOptionLabel: option.label,
            questionText: question.text,
            freeText: freeText
        )
    }
}
