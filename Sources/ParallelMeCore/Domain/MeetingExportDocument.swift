import Foundation

public struct MeetingExportDocument: Equatable, Sendable {
    public var title: String
    public var fileName: String
    public var markdown: String

    public init(state: MeetingFlowState, generatedAt: Date = Date()) {
        let summary = MeetingSummary(state: state)
        self.title = summary.title
        self.fileName = MeetingExportDocument.fileName(title: summary.title, createdAt: state.createdAt)
        self.markdown = MeetingExportDocument.markdown(for: state, summary: summary, generatedAt: generatedAt)
    }

    private static func markdown(
        for state: MeetingFlowState,
        summary: MeetingSummary,
        generatedAt: Date
    ) -> String {
        var lines: [String] = [
            "# \(summary.title)",
            "",
            "- 状态：\(summary.subtitle)",
            "- 创建：\(dateString(state.createdAt))",
            "- 导出：\(dateString(generatedAt))"
        ]

        if let snapshot = state.runtimeSnapshot?.normalized {
            lines.append("- Provider：\(snapshot.providerLabel)")
            if let contextSummary = snapshot.contextSummary {
                lines.append("- 会话上下文：\(contextSummary)")
            }
        }

        appendSection("原始困惑", body: state.rawInput, to: &lines)

        if let context = state.runtimeSnapshot?.normalized.context {
            appendSection("会话上下文", body: context.exportText, to: &lines)
        }

        if !state.definingDialogue.isEmpty {
            appendHeading("书记员定义过程", to: &lines)
            for entry in state.definingDialogue {
                if let question = entry.question {
                    appendBullet(question.text, to: &lines)
                }
                if let answer = entry.answer {
                    appendBullet(answer.exportText, to: &lines)
                }
            }
        }

        if let proposal = state.issueProposal {
            appendHeading("议题提案", to: &lines)
            for row in IssueProposalSnapshot(proposal: proposal).rows where row.isMeaningful {
                appendPair(row.title, row.body, to: &lines)
            }
        }

        let transcript = RoundtableTranscriptSnapshot(record: state.roundtable)
        if !transcript.isEmpty {
            appendHeading("五声圆桌", to: &lines)
            for section in transcript.sections {
                appendPair(section.title, section.detail, to: &lines)
                for opening in section.openingTurns {
                    let snapshot = VoiceOpeningSnapshot(turn: opening)
                    appendPair(snapshot.name, snapshot.thesis, to: &lines)
                    for detail in snapshot.details where detail.isMeaningful {
                        appendPair("\(snapshot.name) · \(detail.title)", detail.body, to: &lines)
                    }
                }
                for turn in section.turns {
                    appendPair(turn.name ?? "圆桌", turn.text, to: &lines)
                }
            }
        }

        if !state.inquiryAnswers.isEmpty {
            appendHeading("书记员问询", to: &lines)
            for answer in state.inquiryAnswers {
                appendPair(answer.question, answer.exportText, to: &lines)
            }
        }

        if let settlement = state.heartSettlement {
            let snapshot = HeartSettlementSnapshot(settlement: settlement)
            appendHeading(snapshot.title, to: &lines)
            for row in snapshot.rows where row.isMeaningful {
                appendPair(row.title, row.body, to: &lines)
            }
        }

        let timeline = MeetingTimeline.items(for: state)
        if !timeline.isEmpty {
            appendHeading("纸页脉络", to: &lines)
            for item in timeline {
                appendBullet("\(item.title)：\(item.detail)", to: &lines)
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func appendHeading(_ heading: String, to lines: inout [String]) {
        lines.append("")
        lines.append("## \(heading)")
        lines.append("")
    }

    private static func appendSection(_ heading: String, body: String?, to lines: inout [String]) {
        guard let body = body.normalizedExportText else { return }
        appendHeading(heading, to: &lines)
        lines.append(body)
    }

    private static func appendPair(_ title: String, _ body: String?, to lines: inout [String]) {
        guard let body = body.normalizedExportText else { return }
        lines.append("- **\(title)**：\(body)")
    }

    private static func appendBullet(_ text: String?, to lines: inout [String]) {
        guard let text = text.normalizedExportText else { return }
        lines.append("- \(text)")
    }

    private static func dateString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func fileName(title: String, createdAt: Date) -> String {
        let date = dateString(createdAt).prefix(10)
        let name = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .map { character in
                character.isUnsafeFileNameCharacter ? "-" : character
            }
        let normalized = String(name)
            .split(separator: "-")
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-. "))
        let suffix = normalized.isEmpty ? "paper" : String(normalized.prefix(48))
        return "ParallelMe-\(date)-\(suffix).md"
    }
}

private extension ProviderContext {
    var exportText: String? {
        let context = normalized
        var lines: [String] = []
        if let meCard = context.meCard {
            lines.append("个人背景：\(meCard)")
        }
        if let tasteProfile = context.tasteProfile {
            lines.append("回应偏好：\(tasteProfile)")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

private extension ScribeAnswer {
    var exportText: String {
        freeText.normalizedExportText ?? selectedOptionLabel.normalizedExportText ?? "已回答"
    }
}

private extension ScribeInquiryAnswer {
    var exportText: String {
        customText.normalizedExportText ?? selectedLabel.normalizedExportText ?? "已回答"
    }
}

private extension Optional where Wrapped == String {
    var normalizedExportText: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

private extension String {
    var normalizedExportText: String? {
        Optional(self).normalizedExportText
    }
}

private extension Character {
    var isUnsafeFileNameCharacter: Bool {
        "/\\?%*|\"<>:".contains(self)
    }
}
