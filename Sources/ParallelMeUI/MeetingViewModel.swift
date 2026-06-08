import Combine
import Foundation
import ParallelMeCore

@MainActor
public final class MeetingViewModel: ObservableObject {
    @Published public var petition: String = ""
    @Published public private(set) var state: MeetingFlowState?
    @Published public private(set) var isBusy = false
    @Published public private(set) var errorMessage: String?
    @Published public var providerMode: ProviderRuntimeMode = .demo
    @Published public var providerBaseURL: String = "https://api.openai.com/v1"
    @Published public var providerModel: String = "gpt-4o-mini"
    @Published public var providerAPIKey: String = ""

    private var coordinator: any MeetingCoordinating
    private let providerSettingsStore: (any ProviderSettingsStoring)?
    private var hasLoadedProviderSettings = false

    public init(
        coordinator: any MeetingCoordinating,
        providerSettingsStore: (any ProviderSettingsStoring)? = nil
    ) {
        self.coordinator = coordinator
        self.providerSettingsStore = providerSettingsStore
    }

    public static func makeDefault() -> MeetingViewModel {
        let coordinator = MeetingSessionCoordinator(
            provider: DemoLLMProvider(),
            repository: FileMeetingRepository.defaultRepository()
        )
        return MeetingViewModel(
            coordinator: coordinator,
            providerSettingsStore: ProviderSettingsRepository.defaultRepository()
        )
    }

    public var providerSettings: ProviderRuntimeSettings {
        ProviderRuntimeSettings(
            mode: providerMode,
            baseURLString: providerBaseURL,
            model: providerModel,
            apiKey: providerAPIKey
        )
    }

    public var canStart: Bool {
        !petition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        providerSettings.isUsable &&
        !isBusy
    }

    public var activeInquiryQuestions: [ScribeInquiryQuestion] {
        guard let state else { return [] }
        let answered = Set(state.inquiryAnswers.map(\.questionID))
        return state.inquiryQuestions.filter { !answered.contains($0.id) }
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func loadProviderSettings() async {
        guard !hasLoadedProviderSettings, let providerSettingsStore else { return }
        hasLoadedProviderSettings = true
        do {
            applyProviderSettings(try await providerSettingsStore.loadSettings())
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func startMeeting() {
        let input = petition
        run { [self] in
            try await self.rebuildCoordinatorIfNeeded()
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

    private func rebuildCoordinatorIfNeeded() async throws {
        try await providerSettingsStore?.saveSettings(providerSettings)
        let provider = try ProviderRuntimeFactory.makeProvider(settings: providerSettings)
        coordinator = MeetingSessionCoordinator(
            provider: provider,
            repository: FileMeetingRepository.defaultRepository()
        )
    }

    private func applyProviderSettings(_ settings: ProviderRuntimeSettings) {
        providerMode = settings.mode
        providerBaseURL = settings.baseURLString
        providerModel = settings.model
        providerAPIKey = settings.apiKey
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
