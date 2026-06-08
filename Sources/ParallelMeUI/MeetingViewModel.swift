import Combine
import Foundation
import ParallelMeCore

@MainActor
public final class MeetingViewModel: ObservableObject {
    @Published public var petition: String = ""
    @Published public private(set) var state: MeetingFlowState?
    @Published public private(set) var recentMeetings: [MeetingSummary] = []
    @Published public private(set) var isBusy = false
    @Published public private(set) var errorMessage: String?
    @Published public var providerMode: ProviderRuntimeMode = .demo
    @Published public var providerBaseURL: String = "https://api.openai.com/v1"
    @Published public var providerModel: String = "gpt-4o-mini"
    @Published public var providerAPIKey: String = ""

    private var coordinator: any MeetingCoordinating
    private let meetingRepository: AnyMeetingRepository
    private let providerSettingsStore: (any ProviderSettingsStoring)?
    private var hasLoadedProviderSettings = false

    public init(
        coordinator: any MeetingCoordinating,
        meetingRepository: any MeetingRepository = InMemoryMeetingRepository(),
        providerSettingsStore: (any ProviderSettingsStoring)? = nil
    ) {
        self.coordinator = coordinator
        self.meetingRepository = AnyMeetingRepository(meetingRepository)
        self.providerSettingsStore = providerSettingsStore
    }

    public static func makeDefault() -> MeetingViewModel {
        let repository = FileMeetingRepository.defaultRepository()
        let coordinator = MeetingSessionCoordinator(
            provider: DemoLLMProvider(),
            repository: repository
        )
        return MeetingViewModel(
            coordinator: coordinator,
            meetingRepository: repository,
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

    public func loadRecentMeetings() async {
        do {
            recentMeetings = try await meetingRepository.list()
                .prefix(5)
                .map(MeetingSummary.init(state:))
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
            await self.loadRecentMeetings()
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

    public func refineProposal(_ feedback: String) {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { [self] in
            self.state = try await self.coordinator.refineProposal(feedback: trimmed)
        }
    }

    public func continueRoundtable() {
        run { [self] in
            let move = RoundtableMove(type: .continueAll)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func askTable(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { [self] in
            let move = RoundtableMove(type: .userToTable, userText: trimmed)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func askVoice(_ voiceID: VoiceID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run { [self] in
            let move = RoundtableMove(type: .userToVoice, targetVoiceID: voiceID, userText: trimmed)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func startDuel(from fromVoiceID: VoiceID, to toVoiceID: VoiceID) {
        guard fromVoiceID != toVoiceID else { return }
        run { [self] in
            let move = RoundtableMove(type: .duel, fromVoiceID: fromVoiceID, toVoiceID: toVoiceID)
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
            await self.loadRecentMeetings()
        }
    }

    public func reviseSettlement(_ revisions: [SettlementModuleID: String]) {
        run { [self] in
            self.state = try await self.coordinator.reviseSettlement(revisions)
            await self.loadRecentMeetings()
        }
    }

    public func restoreMeeting(id: String) {
        run { [self] in
            guard let restored = try await self.meetingRepository.load(id: id) else { return }
            self.state = try await self.coordinator.restore(restored)
        }
    }

    public func deleteMeeting(id: String) {
        run { [self] in
            try await self.meetingRepository.delete(id: id)
            await self.loadRecentMeetings()
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
            repository: meetingRepository
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
                errorMessage = Self.userFacingMessage(for: error)
            }
            isBusy = false
        }
    }

    private static func userFacingMessage(for error: any Error) -> String {
        switch error {
        case MeetingFlowError.emptyPetition:
            return "先写下一句真实困惑，书记员才知道从哪里开始。"
        case MeetingFlowError.incompleteProposal(let missing):
            let labels = missing.map(\.label).joined(separator: "、")
            return "这版议题还差 \(labels)，先别急着进圆桌。"
        case MeetingFlowError.missingRoundtableOpenings:
            return "五声还没有完成开场，等它们先把位置坐稳。"
        case MeetingFlowError.missingAlignmentProfile:
            return "书记员还没拿到足够证据，先回答最后几个关键问题。"
        case MeetingFlowError.missingHeartSettlement:
            return "还没有可修订的本心落定。"
        case MeetingFlowError.missingTaskFrame, MeetingSessionError.missingTaskFrame:
            return "这次议题还没形成可讨论的任务框架，请先修订定义。"
        case MeetingSessionError.noActiveMeeting:
            return "当前没有打开的纸页。"
        case MeetingSessionError.missingProposal:
            return "书记员还没有生成可确认的议题。"
        case MeetingSessionError.emptyFeedback:
            return "写一句你想修订的地方，再让书记员重整。"
        case MeetingSessionError.emptyModelResult:
            return "这次模型没有返回可用内容，请再试一次。"
        case MeetingSessionError.settlementNotReady(let missing):
            let labels = missing.map(\.label).joined(separator: "、")
            return "本心落定还差 \(labels) 的证据。"
        case ProviderRuntimeFactoryError.invalidOpenAICompatibleSettings:
            return "OpenAI 配置还不完整，请检查 Base URL、模型名和 API Key。"
        case OpenAICompatibleProviderError.transport(let statusCode, _):
            return "模型服务返回 \(statusCode)，请检查网络、Key 或服务地址。"
        case OpenAICompatibleProviderError.missingMessageContent:
            return "模型没有返回正文，请再试一次。"
        case OpenAICompatibleProviderError.invalidJSON:
            return "模型返回的结构不符合 ParallelMe 需要的格式，请再试一次。"
        case MockLLMProviderError.missingResponse:
            return "测试 provider 缺少这一阶段的响应。"
        default:
            return "这一步没有完成，请稍后再试。"
        }
    }
}
