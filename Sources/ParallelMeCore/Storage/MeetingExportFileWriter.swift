import Foundation

public struct MeetingExportFile: Equatable, Sendable {
    public var url: URL
    public var document: MeetingExportDocument

    public init(url: URL, document: MeetingExportDocument) {
        self.url = url
        self.document = document
    }
}

public struct MeetingExportFileWriter: Sendable {
    public var directoryURL: URL

    public init(
        directoryURL: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ParallelMeExports", isDirectory: true)
    ) {
        self.directoryURL = directoryURL
    }

    public func write(document: MeetingExportDocument) throws -> MeetingExportFile {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL.appendingPathComponent(document.fileName, isDirectory: false)
        try Data(document.markdown.utf8).write(to: fileURL, options: [.atomic])
        return MeetingExportFile(url: fileURL, document: document)
    }
}
