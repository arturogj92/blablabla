import Foundation

@MainActor
final class TranscriptStore {
    private let saveURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("Blablabla", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        self.saveURL = folder.appendingPathComponent("transcripts.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [TranscriptRecord] {
        guard let data = try? Data(contentsOf: saveURL) else {
            return []
        }

        return (try? decoder.decode([TranscriptRecord].self, from: data)) ?? []
    }

    func save(_ records: [TranscriptRecord]) {
        guard let data = try? encoder.encode(records) else {
            return
        }

        try? data.write(to: saveURL, options: .atomic)
    }
}
