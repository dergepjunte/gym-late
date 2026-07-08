import Foundation

/// UserDefaults-based replacement for localStorage
final class LocalStore {
    static let shared = LocalStore()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Active Group

    var activeGroup: GroupInfo? {
        get { decode(GroupInfo.self, forKey: "gymGroup") }
        set { encode(newValue, forKey: "gymGroup") }
    }

    // MARK: - All Groups (multi-group)

    var allGroups: [GroupInfo] {
        get { decode([GroupInfo].self, forKey: "gymGroups") ?? [] }
        set { encode(newValue, forKey: "gymGroups") }
    }

    func addGroup(_ g: GroupInfo) {
        var all = allGroups
        if !all.contains(where: { $0.id == g.id }) { all.append(g) }
        allGroups = all
    }

    func removeGroup(id: String) {
        allGroups = allGroups.filter { $0.id != id }
    }

    // MARK: - User Profile per group

    func userProfile(for groupId: String) -> UserProfile? {
        decode(UserProfile.self, forKey: "gymUser_\(groupId)")
    }

    func saveUserProfile(_ profile: UserProfile, for groupId: String) {
        encode(profile, forKey: "gymUser_\(groupId)")
    }

    func clearUserProfile(for groupId: String) {
        defaults.removeObject(forKey: "gymUser_\(groupId)")
    }

    // MARK: - Daily flags (seen today)

    func wrappedSeenKey(for weekStart: String) -> String { "gymWrappedSeen_\(weekStart)" }
    func dailyHypeSeenKey(for date: String) -> String { "gymDailyHypeSeen_\(date)" }
    func geoPromptSeenKey(for date: String) -> String { "gymGeoPromptSeen_\(date)" }

    func markWrappedSeen(weekStart: String) {
        defaults.set(true, forKey: wrappedSeenKey(for: weekStart))
    }
    func isWrappedSeen(weekStart: String) -> Bool {
        defaults.bool(forKey: wrappedSeenKey(for: weekStart))
    }

    func markDailyHypeSeen(date: String) {
        defaults.set(true, forKey: dailyHypeSeenKey(for: date))
    }
    func isDailyHypeSeen(date: String) -> Bool {
        defaults.bool(forKey: dailyHypeSeenKey(for: date))
    }

    func markGeoPromptSeen(date: String) {
        defaults.set(true, forKey: geoPromptSeenKey(for: date))
    }
    func isGeoPromptSeen(date: String) -> Bool {
        defaults.bool(forKey: geoPromptSeenKey(for: date))
    }

    func clearDailyFlags(for date: String) {
        defaults.removeObject(forKey: dailyHypeSeenKey(for: date))
        defaults.removeObject(forKey: geoPromptSeenKey(for: date))
    }

    // MARK: - Admin (in-memory only — never persisted)

    var adminPassword: String? = nil
    var adminMode: Bool { adminPassword != nil }

    // MARK: - Private helpers

    private func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value = value else {
            defaults.removeObject(forKey: key)
            return
        }
        let data = try? JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
