import Combine
import Foundation
import ParallelMeCore

@MainActor
public final class MeetingViewModel: ObservableObject {
    @Published public var petition: String = ""
    @Published public private(set) var state: MeetingFlowState?
    @Published public private(set) var resumableMeeting: MeetingSummary?
    @Published public private(set) var meetingLibrary = MeetingLibrarySnapshot()
    @Published public private(set) var sessionEvents: [MeetingSessionEvent] = []
    @Published public private(set) var sessionDiagnostics = MeetingSessionDiagnosticsSnapshot()
    @Published public private(set) var isBusy = false
    @Published public private(set) var activity: MeetingActivitySnapshot?
    @Published public private(set) var errorMessage: String?
    @Published public var providerMode: ProviderRuntimeMode = .demo
    @Published public var providerBaseURL: String = "https://api.openai.com/v1"
    @Published public var providerModel: String = "gpt-4o-mini"
    @Published public var providerAPIKey: String = ""
    @Published public var contextMeCard: String = ""
    @Published public var contextTasteProfile: String = ""
    @Published public var librarySearchText: String = ""
    @Published public var libraryFilter: MeetingLibraryFilter = .all
    @Published public private(set) var runtimePreferencesMessage: String?

    private var coordinator: any MeetingCoordinating
    private let meetingRepository: AnyMeetingRepository
    private let providerSettingsStore: (any ProviderSettingsStoring)?
    private let providerContextStore: (any ProviderContextStoring)?
    private let sessionEventSink: InMemoryMeetingSessionEventSink?
    private let providerFactory: (ProviderRuntimeSettings) throws -> AnyLLMProvider
    private var hasLoadedProviderSettings = false
    private var hasLoadedProviderContext = false

    public init(
        coordinator: any MeetingCoordinating,
        meetingRepository: any MeetingRepository = InMemoryMeetingRepository(),
        providerSettingsStore: (any ProviderSettingsStoring)? = nil,
        providerContextStore: (any ProviderContextStoring)? = nil,
        sessionEventSink: InMemoryMeetingSessionEventSink? = nil,
        providerFactory: @escaping (ProviderRuntimeSettings) throws -> AnyLLMProvider = ProviderRuntimeFactory.makeProvider
    ) {
        self.coordinator = coordinator
        self.meetingRepository = AnyMeetingRepository(meetingRepository)
        self.providerSettingsStore = providerSettingsStore
        self.providerContextStore = providerContextStore
        self.sessionEventSink = sessionEventSink
        self.providerFactory = providerFactory
    }

    public static func makeDefault() -> MeetingViewModel {
        let repository = FileMeetingRepository.defaultRepository()
        let sessionEventSink = InMemoryMeetingSessionEventSink()
        let coordinator = MeetingSessionCoordinator(
            provider: DemoLLMProvider(),
            repository: repository,
            eventSink: sessionEventSink
        )
        return MeetingViewModel(
            coordinator: coordinator,
            meetingRepository: repository,
            providerSettingsStore: ProviderSettingsRepository.defaultRepository(),
            providerContextStore: FileProviderContextStore.defaultStore(),
            sessionEventSink: sessionEventSink
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
        startReadiness.canStart
    }

    public var startReadiness: MeetingStartReadinessSnapshot {
        MeetingStartReadinessSnapshot(
            petition: petition,
            providerSettings: providerSettings,
            isBusy: isBusy
        )
    }

    public var activeInquiryQuestions: [ScribeInquiryQuestion] {
        guard let state else { return [] }
        let answered = Set(state.inquiryAnswers.map(\.questionID))
        return state.inquiryQuestions.filter { !answered.contains($0.id) }
    }

    public var providerContext: ProviderContext? {
        let context = ProviderContext(
            meCard: contextMeCard,
            tasteProfile: contextTasteProfile
        ).normalized
        return context.isEmpty ? nil : context
    }

    public var visibleMeetingLibrary: MeetingLibrarySnapshot {
        meetingLibrary.filtered(searchText: librarySearchText, filter: libraryFilter)
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func dismissRuntimePreferencesMessage() {
        runtimePreferencesMessage = nil
    }

    public func useStarterPrompt(_ prompt: PetitionStarterPrompt) {
        guard !isBusy else { return }
        petition = prompt.seedText
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

    public func loadProviderContext() async {
        guard !hasLoadedProviderContext, let providerContextStore else { return }
        hasLoadedProviderContext = true
        do {
            applyProviderContext(try await providerContextStore.loadContext())
        } catch {
            errorMessage = Self.userFacingMessage(for: error)
        }
    }

    public func loadMeetingLibrary() async {
        do {
            let states = try await meetingRepository.list()
            let library = MeetingLibrarySnapshot(states: states)
            meetingLibrary = library
            resumableMeeting = library.resumable
        } catch {
            errorMessage = Self.userFacingMessage(for: error)
        }
    }

    public func saveRuntimePreferences() {
        run(activity: .savingRuntimePreferences) { [self] in
            try await self.persistRuntimePreferences()
            self.runtimePreferencesMessage = "运行配置已保存到本机。"
        }
    }

    public func clearRuntimePreferences() {
        run(activity: .clearingRuntimePreferences) { [self] in
            try await self.providerSettingsStore?.clearSettings()
            try await self.providerContextStore?.clearContext()
            self.applyProviderSettings(ProviderRuntimeSettings())
            self.applyProviderContext(ProviderContext())
            self.runtimePreferencesMessage = "运行配置已清空。"
        }
    }

    public func loadSessionEvents() async {
        guard let sessionEventSink else { return }
        let snapshot = MeetingSessionDiagnosticsSnapshot(events: await sessionEventSink.allEvents())
        sessionDiagnostics = snapshot
        sessionEvents = snapshot.recentEvents
    }

    public func startMeeting() {
        let input = petition
        run(activity: .startingMeeting) { [self] in
            try await self.rebuildCoordinatorIfNeeded()
            let started = try await self.coordinator.start(rawInput: input)
            self.state = started
            self.state = try await self.coordinator.requestDefinition()
            await self.loadMeetingLibrary()
        }
    }

    public func answerProbe(
        question: ScribeQuestion,
        option: ScribeProbeOption,
        customText: String? = nil
    ) {
        let trimmedCustomText = customText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if option.isCustomAnswer, trimmedCustomText?.isEmpty != false { return }

        run(activity: .submittingDefinitionAnswers) { [self] in
            let answer = ScribeAnswer(
                questionID: question.id,
                selectedOptionID: option.id,
                selectedOptionLabel: option.label,
                questionText: question.text,
                freeText: option.isCustomAnswer ? trimmedCustomText : nil
            )
            self.state = try await self.submitProbeAnswersToCoordinator([answer])
        }
    }

    public func submitProbeAnswers(_ answers: [ScribeAnswer]) {
        guard !answers.isEmpty else { return }
        run(activity: .submittingDefinitionAnswers) { [self] in
            self.state = try await self.submitProbeAnswersToCoordinator(answers)
        }
    }

    public func confirmProposal() {
        run(activity: .confirmingProposal) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            self.state = try await self.coordinator.confirmProposalAndOpenRoundtable()
        }
    }

    public func retryDefinition() {
        run(activity: .retryingDefinition) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            self.state = try await self.coordinator.requestDefinition()
            await self.loadMeetingLibrary()
        }
    }

    public func refineProposal(_ feedback: String) {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run(activity: .refiningProposal) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            self.state = try await self.coordinator.refineProposal(feedback: trimmed)
        }
    }

    public func continueRoundtable() {
        run(activity: .continuingRoundtable) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            let move = RoundtableMove(type: .continueAll)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func askTable(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run(activity: .askingTable) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            let move = RoundtableMove(type: .userToTable, userText: trimmed)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func askVoice(_ voiceID: VoiceID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        run(activity: .askingVoice) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            let move = RoundtableMove(type: .userToVoice, targetVoiceID: voiceID, userText: trimmed)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func startDuel(from fromVoiceID: VoiceID, to toVoiceID: VoiceID) {
        guard fromVoiceID != toVoiceID else { return }
        run(activity: .startingDuel) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            let move = RoundtableMove(type: .duel, fromVoiceID: fromVoiceID, toVoiceID: toVoiceID)
            self.state = try await self.coordinator.submitRoundtableMove(move)
        }
    }

    public func startInquiry() {
        run(activity: .startingInquiry) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            self.state = try await self.coordinator.startInquiry()
        }
    }

    public func retryInquiry() {
        run(activity: .retryingInquiry) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            self.state = try await self.coordinator.requestNextInquiry()
            await self.loadMeetingLibrary()
        }
    }

    public func answerInquiry(
        question: ScribeInquiryQuestion,
        option: ScribeInquiryOption,
        customText: String? = nil
    ) {
        let trimmedCustomText = customText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if option.isCustomAnswer, trimmedCustomText?.isEmpty != false { return }

        run(activity: .submittingInquiryAnswers) { [self] in
            let answer = ScribeInquiryAnswer(
                questionID: question.id,
                question: question.question,
                selectedOptionID: option.id,
                selectedLabel: option.label,
                customText: option.isCustomAnswer ? trimmedCustomText : nil
            )
            self.state = try await self.submitInquiryAnswersToCoordinator([answer])
        }
    }

    public func submitInquiryAnswers(_ answers: [ScribeInquiryAnswer]) {
        guard !answers.isEmpty else { return }
        run(activity: .submittingInquiryAnswers) { [self] in
            self.state = try await self.submitInquiryAnswersToCoordinator(answers)
        }
    }

    public func requestSettlement() {
        run(activity: .requestingSettlement) { [self] in
            _ = try await self.rebuildCoordinatorIfNeeded(restoring: self.state)
            self.state = try await self.coordinator.requestSettlement()
        }
    }

    public func archive() {
        run(activity: .archivingPaper) { [self] in
            self.state = try await self.coordinator.archive()
            await self.loadMeetingLibrary()
        }
    }

    public func reviseSettlement(_ revisions: [SettlementModuleID: String]) {
        run(activity: .revisingSettlement) { [self] in
            self.state = try await self.coordinator.reviseSettlement(revisions)
            await self.loadMeetingLibrary()
        }
    }

    public func restoreMeeting(id: String) {
        run(activity: .restoringPaper) { [self] in
            guard let restored = try await self.meetingRepository.load(id: id) else { return }
            if restored.stage == .archived {
                self.state = try await self.coordinator.restore(restored)
            } else {
                self.state = try await self.rebuildCoordinatorIfNeeded(restoring: restored)
            }
            await self.loadMeetingLibrary()
        }
    }

    public func deleteMeeting(id: String) {
        run(activity: .deletingPaper) { [self] in
            try await self.meetingRepository.delete(id: id)
            await self.loadMeetingLibrary()
        }
    }

    public func closeCurrentPaper() {
        guard !isBusy else { return }
        petition = ""
        state = nil
        errorMessage = nil
        Task { @MainActor in
            await self.loadMeetingLibrary()
            await self.loadSessionEvents()
        }
    }

    public func reset() {
        closeCurrentPaper()
    }

    @discardableResult
    private func rebuildCoordinatorIfNeeded(restoring restoredState: MeetingFlowState? = nil) async throws -> MeetingFlowState? {
        try await persistRuntimePreferences()
        let provider = try providerFactory(providerSettings)
        let restoredSnapshot = restoredState?.runtimeSnapshot?.normalized
        let effectiveContext = providerContext ?? restoredSnapshot?.context
        let effectiveSnapshot = MeetingRuntimeSnapshot(settings: providerSettings, context: effectiveContext).normalized
        let stateToRestore = restoredState.map { state in
            var next = state
            next.runtimeSnapshot = effectiveSnapshot
            return next
        }
        if let sessionEventSink {
            coordinator = MeetingSessionCoordinator(
                provider: provider,
                repository: meetingRepository,
                eventSink: sessionEventSink,
                context: effectiveContext,
                runtimeSnapshot: effectiveSnapshot
            )
        } else {
            coordinator = MeetingSessionCoordinator(
                provider: provider,
                repository: meetingRepository,
                context: effectiveContext,
                runtimeSnapshot: effectiveSnapshot
            )
        }
        if let stateToRestore {
            return try await coordinator.restore(stateToRestore)
        }
        return nil
    }

    private var runtimeSnapshot: MeetingRuntimeSnapshot {
        MeetingRuntimeSnapshot(settings: providerSettings, context: providerContext)
    }

    private func submitProbeAnswersToCoordinator(_ answers: [ScribeAnswer]) async throws -> MeetingFlowState {
        _ = try await rebuildCoordinatorIfNeeded(restoring: state)
        return try await coordinator.submitProbeAnswers(answers)
    }

    private func submitInquiryAnswersToCoordinator(_ answers: [ScribeInquiryAnswer]) async throws -> MeetingFlowState {
        _ = try await rebuildCoordinatorIfNeeded(restoring: state)
        return try await coordinator.submitInquiryAnswers(answers)
    }

    private func persistRuntimePreferences() async throws {
        try await providerSettingsStore?.saveSettings(providerSettings)
        try await providerContextStore?.saveContext(
            ProviderContext(meCard: contextMeCard, tasteProfile: contextTasteProfile)
        )
    }

    private func applyProviderSettings(_ settings: ProviderRuntimeSettings) {
        providerMode = settings.mode
        providerBaseURL = settings.baseURLString
        providerModel = settings.model
        providerAPIKey = settings.apiKey
    }

    private func applyProviderContext(_ context: ProviderContext) {
        contextMeCard = context.normalized.meCard ?? ""
        contextTasteProfile = context.normalized.tasteProfile ?? ""
    }

    private func run(
        activity activityKind: MeetingActivityKind,
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        guard !isBusy else { return }
        isBusy = true
        activity = MeetingActivitySnapshot(kind: activityKind)
        errorMessage = nil
        Task { @MainActor in
            do {
                try await operation()
            } catch {
                if let latestState = await coordinator.currentState() {
                    state = latestState
                }
                let message = Self.userFacingMessage(for: error)
                errorMessage = message
                await sessionEventSink?.record(
                    MeetingSessionEvent(
                        meetingID: state?.id,
                        kind: .failed,
                        message: message,
                        trace: [String(describing: error)]
                    )
                )
            }
            await loadSessionEvents()
            activity = nil
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
        case MeetingFlowError.incompleteProbeAnswers(let missingQuestionIDs):
            return "本轮还有 \(missingQuestionIDs.count) 个定义问题没回答，先一起补齐。"
        case MeetingFlowError.incompleteInquiryAnswers(let missingQuestionIDs):
            return "本轮还有 \(missingQuestionIDs.count) 个问询问题没回答，先一起补齐。"
        case MeetingFlowError.missingRoundtableOpenings:
            return "五声还没有完成开场，等它们先把位置坐稳。"
        case MeetingFlowError.incompleteRoundtableOpenings(let missing):
            let labels = missing.map(\.displayName).joined(separator: "、")
            return "五声开场还缺 \(labels)，不能带着空位进入问询。"
        case MeetingFlowError.missingRoundtableExchange:
            return "先让圆桌至少完成一轮具体交换，再进入书记员问询。"
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
