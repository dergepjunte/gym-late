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

    // MARK: - Geo check-in opt-out (website: localStorage 'gymGeoEnabled')

    var geoEnabled: Bool {
        get { defaults.string(forKey: "gymGeoEnabled") != "0" }
        set { defaults.set(newValue ? "1" : "0", forKey: "gymGeoEnabled") }
    }

    func clearWrappedSeen(weekStart: String) {
        defaults.removeObject(forKey: wrappedSeenKey(for: weekStart))
    }

    // MARK: - Notification preferences

    var notifReminders: Bool {
        get { defaults.object(forKey: "gymNotifReminders") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "gymNotifReminders") }
    }
    var notifStreak: Bool {
        get { defaults.object(forKey: "gymNotifStreak") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "gymNotifStreak") }
    }
    var notifActivity: Bool {
        get { defaults.object(forKey: "gymNotifActivity") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "gymNotifActivity") }
    }
    var reminderTime: String {
        get { defaults.string(forKey: "gymReminderTime") ?? "09:00" }
        set { defaults.set(newValue, forKey: "gymReminderTime") }
    }
    var quietStart: String {
        get { defaults.string(forKey: "gymQuietStart") ?? "22:00" }
        set { defaults.set(newValue, forKey: "gymQuietStart") }
    }
    var quietEnd: String {
        get { defaults.string(forKey: "gymQuietEnd") ?? "08:00" }
        set { defaults.set(newValue, forKey: "gymQuietEnd") }
    }
    var notifMembers: [String]? {
        get { decode([String].self, forKey: "gymNotifMembers") }
        set { encode(newValue, forKey: "gymNotifMembers") }
    }

    // MARK: - Notification primer (one-time onboarding screen)

    var notifPrimerSeen: Bool {
        get { defaults.bool(forKey: "gymNotifPrimerSeen") }
        set { defaults.set(newValue, forKey: "gymNotifPrimerSeen") }
    }

    // MARK: - Global Account
    //
    // Only the non-secret fields live here; the bearer `accountToken` is
    // stored in Keychain only (see KeychainStore) and combined back into a
    // full AccountInfo at read time by AppState.

    private struct AccountMeta: Codable {
        var accountId: String
        var email: String?
        var hasPassword: Bool
        var providers: AccountProviders
    }

    private var accountMeta: AccountMeta? {
        get { decode(AccountMeta.self, forKey: "gymAccountMeta") }
        set { encode(newValue, forKey: "gymAccountMeta") }
    }

    private static let accountTokenKey = "gymAccountToken"

    var account: AccountInfo? {
        get {
            guard let meta = accountMeta, let token = KeychainStore.read(key: Self.accountTokenKey) else { return nil }
            return AccountInfo(accountId: meta.accountId, email: meta.email, accountToken: token,
                               hasPassword: meta.hasPassword, providers: meta.providers)
        }
        set {
            guard let info = newValue else {
                accountMeta = nil
                KeychainStore.delete(key: Self.accountTokenKey)
                return
            }
            accountMeta = AccountMeta(accountId: info.accountId, email: info.email,
                                      hasPassword: info.hasPassword, providers: info.providers)
            KeychainStore.save(info.accountToken, key: Self.accountTokenKey)
        }
    }

    /// A user has migrated a group locally once their stored profile for it
    /// no longer carries a recovery code (server omits it once account-linked
    /// registrations/logins are in play — see UserProfile.recoveryCode).
    var migratableGroupLinks: [LinkRecoveryItem] {
        allGroups.compactMap { g in
            guard let p = userProfile(for: g.id), let code = p.recoveryCode, !code.isEmpty else { return nil }
            return LinkRecoveryItem(groupId: g.id, userId: p.userId, recoveryCode: code)
        }
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
