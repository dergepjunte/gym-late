import Foundation

// MARK: - Group & People

struct GroupInfo: Codable, Identifiable {
    var id: String
    var code: String
    var name: String
}

struct GroupData: Codable {
    var id: String
    var code: String
    var name: String
    var gymDays: String
    var gymLat: Double?
    var gymLng: Double?
    var gymRadius: Int?
    var fixedCheckinEnabled: Bool
    var checkinTimeDate: String?
    var checkinTime: String?
    var people: [Person]
    var entries: [Entry]
}

struct Person: Codable, Identifiable {
    var id: String
    var name: String
    var avatarEmoji: String
    var avatarColor: String
    var avatarImg: String?
    var isCreator: Bool
    var streak: Int
    var freezes: Int
    var availDays: String?
    var availEditedAt: Int?
}

struct Entry: Codable, Identifiable {
    var id: String
    var person: String
    var date: String
    var mins: Int
    var ts: Int
    var type: String  // "late" | "skip" | "attend"
    var reason: String?
    var auto: Bool?   // true = server-generated no-show skip (still counts as a streak miss)

    private enum CodingKeys: String, CodingKey {
        case id, person, date, mins, ts, type, reason, auto
    }

    init(id: String, person: String, date: String, mins: Int, ts: Int,
         type: String, reason: String? = nil, auto: Bool? = nil) {
        self.id = id; self.person = person; self.date = date; self.mins = mins
        self.ts = ts; self.type = type; self.reason = reason; self.auto = auto
    }

    // Custom decode: `auto` is tolerant of both a JSON boolean and a JSON
    // number (0/1), so a server that forgets to normalize a TINYINT column
    // (as ours briefly did) can't silently fail the *entire* entries array —
    // one bad element otherwise throws JSONDecoder.typeMismatch for the whole
    // GroupData response, which AppState then masks by falling back to
    // cached/outbox data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        person = try c.decode(String.self, forKey: .person)
        date = try c.decode(String.self, forKey: .date)
        mins = try c.decode(Int.self, forKey: .mins)
        ts = try c.decode(Int.self, forKey: .ts)
        type = try c.decode(String.self, forKey: .type)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .auto) {
            auto = b
        } else if let n = try? c.decodeIfPresent(Int.self, forKey: .auto) {
            auto = (n != 0)
        } else {
            auto = nil
        }
    }
}

// MARK: - Local User Profile

struct UserProfile: Codable {
    var userId: String
    var name: String
    var avatarEmoji: String
    var avatarColor: String
    var avatarImg: String?
    // nil for profiles registered while signed into a global account (no
    // recovery code is issued for those — see AccountInfo below).
    var recoveryCode: String?
    var isCreator: Bool
}

// MARK: - API Responses

struct RegisterResponse: Codable {
    var userId: String
    var name: String
    var avatarEmoji: String
    var avatarColor: String
    var avatarImg: String?
    // Omitted by the server when the registration was made with an
    // accountToken (account-linked registrations never get a recovery code).
    var recoveryCode: String?
    var isCreator: Bool
}

// MARK: - Global Account (email/password + Apple/Google SSO)

struct AccountProviders: Codable {
    var apple: Bool
    var google: Bool
}

/// Returned by every /api/account/* auth endpoint. `accountToken` is the
/// long-lived bearer secret — store it in Keychain only, never UserDefaults.
struct AccountInfo: Codable {
    var accountId: String
    var email: String?
    var accountToken: String
    var hasPassword: Bool
    var providers: AccountProviders
}

struct AccountGroup: Codable {
    var id: String
    var code: String
    var name: String
    var profile: UserProfile
}

struct AccountGroupsResponse: Codable {
    var groups: [AccountGroup]
}

struct LinkRecoveryItem: Encodable {
    var groupId: String
    var userId: String
    var recoveryCode: String
}

struct LinkRecoveryResponse: Codable {
    var linked: [String]
    var failed: [String]
}

struct LoginResponse: Codable {
    var userId: String
    var name: String
    var avatarEmoji: String
    var avatarColor: String
    var avatarImg: String?
    var isCreator: Bool
}

struct ChestResult: Codable {
    var got_freeze: Bool
    var streak: Int
    var freezes: Int
}

struct CreateEntryResponse: Codable {
    var ok: Bool
    var id: String
    var chest: ChestResult?
}

struct OkResponse: Codable {
    var ok: Bool
}

// MARK: - Helpers

extension GroupData {
    /// Entries for this week (Mon–Sun of current ISO week)
    func entriesThisWeek() -> [Entry] {
        let cal = Calendar.iso8601UTC
        let today = Date()
        let mon = cal.startOfWeek(for: today)
        let sun = cal.date(byAdding: .day, value: 6, to: mon)!
        let monStr = dateYMD(mon)
        let sunStr = dateYMD(sun)
        return entries.filter { $0.date >= monStr && $0.date <= sunStr }
    }

    func person(named name: String) -> Person? {
        people.first { $0.name.lowercased() == name.lowercased() }
    }
}

func dateYMD(_ d: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.timeZone = TimeZone(identifier: "UTC")
    return fmt.string(from: d)
}

func parseDate(_ s: String) -> Date? {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.timeZone = TimeZone(identifier: "UTC")
    return fmt.date(from: s)
}

extension Calendar {
    static var iso8601UTC: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func startOfWeek(for date: Date) -> Date {
        var comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        comps.weekday = 2 // Monday
        return self.date(from: comps)!
    }
}
