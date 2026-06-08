import Combine
import Foundation
import ParallelMeCore

@MainActor
public final class MeetingViewModel: ObservableObject {
    @Published public var petition: String = ""
    @Published public private(set) var state: MeetingFlowState?
    @Published public private(set) var isBusy = false
    @Published public private(set) var errorMessage: String?

    private let coordinator: any MeetingCoordinating

    public init(coordinator: any MeetingCoordinating) {
        self.coordinator = coordinator
    }

    public static func makeDefault() -> MeetingViewModel {
        let coordinator = MeetingSessionCoordinator(
            provider: DemoLLMProvider(),
            repository: FileMeetingRepository.defaultRepository()
        )
        return MeetingViewModel(coordinator: coordinator)
    }

    public var canStart: Bool {
        !petition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    public var activeInquiryQuestions: [ScribeInquiryQuestion] {
        guard let state else { return [] }
        let answered = Set(state.inquiryAnswers.map(\.questionID))
        return state.inquiryQuestions.filter { !answered.contains($0.id) }
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func startMeeting() {
        let input = petition
        run { [self] in
            let started = try await self.coordinator.start(rawInput: input)
            self.state = started
            self.state = try await self.coordinator.requestDefinition()
        }
    }

    public func answerProbe(question: ScribeQuestion, option: ScribeProbeOption) {
        run { [self] in
            let answer = ScribeAnswer(
                questionID: question.id,
                selectedOptionID: option.id,
                selectedOptionLabel: option.label,
                questionText: question.text
            )
            self.state = try await self.coordinator.submitProbeAnswers([answer])
        }
    }

    public func confirmProposal() {
        run { [self] in
            self.state = try await self.coordinator.confirmProposalAndOpenRoundtable()
        }
    }

    public func continueRoundtable() {
        run { [self] in
            let move = RoundtableMove(type: .continueAll)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func startInquiry() {
        run { [self] in
            self.state = try await self.coordinator.startInquiry()
        }
    }

    public func answerInquiry(question: ScribeInquiryQuestion, option: ScribeInquiryOption) {
        run { [self] in
            let answer = ScribeInquiryAnswer(
                questionID: question.id,
                question: question.question,
                selectedOptionID: option.id,
                selectedLabel: option.label
            )
            self.state = try await self.coordinator.submitInquiryAnswers([answer])
        }
    }

    public func requestSettlement() {
        run { [self] in
            self.state = try await self.coordinator.requestSettlement()
        }
    }

    public func archive() {
        run { [self] in
            self.state = try await self.coordinator.archive()
        }
    }

    public func reset() {
        petition = ""
        state = nil
        errorMessage = nil
        isBusy = false
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        Task { @MainActor in
            do {
                try await operation()
            } catch {
                errorMessage = String(describing: error)
            }
            isBusy = false
        }
    }
}
