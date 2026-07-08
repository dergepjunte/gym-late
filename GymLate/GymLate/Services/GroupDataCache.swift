import Foundation

struct CachedGroupData: Codable {
    var data: GroupData
    var fetchedAt: Date
}

/// Persists the last-known GroupData per group as JSON files in Application
/// Support, so the app can render instantly without a server connection.
final class GroupDataCache {
    static let shared = GroupDataCache()

    private let dir: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        dir = base.appendingPathComponent("GroupDataCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func fileURL(for groupId: String) -> URL {
        dir.appendingPathComponent("\(groupId).json")
    }

    func load(groupId: String) -> CachedGroupData? {
        guard let raw = try? Data(contentsOf: fileURL(for: groupId)) else { return nil }
        return try? JSONDecoder().decode(CachedGroupData.self, from: raw)
    }

    func save(_ data: GroupData, groupId: String) {
        let cached = CachedGroupData(data: data, fetchedAt: Date())
        guard let raw = try? JSONEncoder().encode(cached) else { return }
        try? raw.write(to: fileURL(for: groupId), options: .atomic)
    }

    func remove(groupId: String) {
        try? FileManager.default.removeItem(at: fileURL(for: groupId))
    }
}
