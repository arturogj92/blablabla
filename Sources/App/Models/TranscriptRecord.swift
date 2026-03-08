import Foundation

struct TranscriptRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    let insertedIntoFocusedApp: Bool

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, insertedIntoFocusedApp: Bool) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.insertedIntoFocusedApp = insertedIntoFocusedApp
    }
}
