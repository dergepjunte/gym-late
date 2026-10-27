import Foundation

// MARK: - Group chat + time proposals

struct ChatMessage: Codable, Identifiable, Equatable {
    var id: String
    var userId: String
    /// "text" | "time_proposal" | "system"
    var kind: String
    var text: String?
    var propDate: String?
    var propTime: String?
    /// Nur Vorschlaege: "open" | "accepted" | "rejected" | "superseded"
    var status: String?
    var createdAt: Double
    var yes: [String]
    var no: [String]

    var isProposal: Bool { kind == "time_proposal" }
}

struct ChatSnapshot: Codable {
    var members: Int
    var messages: [ChatMessage]
}

/// Anmeldedaten fuer die Chat-Endpunkte (wie bei Eintraegen: Recovery-Code oder Konto-Token).
struct ChatAuth {
    var userId: String
    var recoveryCode: String?
    var accountToken: String?
}
