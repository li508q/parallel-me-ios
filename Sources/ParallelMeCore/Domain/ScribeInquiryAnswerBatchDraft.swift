import Foundation

public struct ScribeInquiryAnswerSelection: Codable, Equatable, Sendable {
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

public struct ScribeInquiryAnswerBatchDraft: Codable, Equatable, Sendable {
    public private(set) var selectionsByQuestionID: [String: ScribeInquiryAnswerSelection]

    public init(selections: [ScribeInquiryAnswerSelection] = []) {
        var selectionsByQuestionID: [String: ScribeInquiryAnswerSelection] = [:]
        for selection in selections {
            selectionsByQuestionID[selection.questionID] = selection
        }
        self.selectionsByQuestionID = selectionsByQuestionID
    }

    public func selection(for questionID: String) -> ScribeInquiryAnswerSelection? {
        selectionsByQuestionID[questionID]
    }

    public mutating func select(
        question: ScribeInquiryQuestion,
        option: ScribeInquiryOption,
        customText: String? = nil
    ) {
        selectionsByQuestionID[question.id] = ScribeInquiryAnswerSelection(
            questionID: question.id,
            selectedOptionID: option.id,
            customText: option.isCustomAnswer ? customText : nil
        )
    }

    public func canSubmit(questions: [ScribeInquiryQuestion]) -> Bool {
        missingQuestionIDs(in: questions).isEmpty
    }

    public func missingQuestionIDs(in questions: [ScribeInquiryQuestion]) -> [String] {
        questions.compactMap { question in
            answer(for: question) == nil ? question.id : nil
        }
    }

    public func answers(for questions: [ScribeInquiryQuestion]) -> [ScribeInquiryAnswer] {
        questions.compactMap(answer(for:))
    }

    private func answer(for question: ScribeInquiryQuestion) -> ScribeInquiryAnswer? {
        guard let selection = selectionsByQuestionID[question.id],
              let option = question.options.first(where: { $0.id == selection.selectedOptionID }) else {
            return nil
        }

        let customText: String?
        if option.isCustomAnswer {
            guard let normalized = selection.customText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !normalized.isEmpty else {
                return nil
            }
            customText = normalized
        } else {
            customText = nil
        }

        return ScribeInquiryAnswer(
            questionID: question.id,
            question: question.question,
            selectedOptionID: option.id,
            selectedLabel: option.label,
            customText: customText
        )
    }
}
