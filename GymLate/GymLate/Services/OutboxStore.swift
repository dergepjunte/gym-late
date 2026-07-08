import Foundation

/// A write that could not reach the server yet. Replayed FIFO once online.
struct PendingMutation: Codable, Identifiable {
    let id: UUID
    let groupId: String
    let createdAt: Date
    var attempts: Int
    let payload: Payload

    enum Payload: Codable {
        case logEntry(person: String, date: String, type: String,
                      mins: Int?, reason: String?, localEntryId: String)
        case deleteEntry(entryId: String, actorUserId: String?, actorRecoveryCode: String?)
        case patchUser(userId: String, name: String?, avatarEmoji: String?,
                       avatarColor: String?, avatarImg: String?,
                       availDays: String?, recoveryCode: String)
        case patchGroup(gymDays: String?, fixedCheckinEnabled: Bool?,
                        creatorUserId: String, creatorRecoveryCode: String)
    }
}

/// Persistent FIFO queue of offline writes, stored as JSON in Application Support.
final class OutboxStore {
    static let shared = OutboxStore()

    private(set) var all: [PendingMutation] = []
    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("GroupDataCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("outbox.json")
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PendingMutation].self, from: raw) {
            all = decoded
        }
    }

    var count: Int { all.count }

    func enqueue(_ m: PendingMutation) {
        all.append(m)
        persist()
    }

    func remove(id: UUID) {
        all.removeAll { $0.id == id }
        persist()
    }

    func removeAll(for groupId: String) {
        all.removeAll { $0.groupId == groupId }
        persist()
    }

    func pending(for groupId: String) -> [PendingMutation] {
        all.filter { $0.groupId == groupId }
    }

    func markAttempt(id: UUID) {
        if let i = all.firstIndex(where: { $0.id == id }) {
            all[i].attempts += 1
            persist()
        }
    }

    private func persist() {
        guard let raw = try? JSONEncoder().encode(all) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }
}
