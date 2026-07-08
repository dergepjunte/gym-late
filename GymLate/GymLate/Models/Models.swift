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
}

// MARK: - Local User Profile

struct UserProfile: Codable {
    var userId: String
    var name: String
    var avatarEmoji: String
    var avatarColor: String
    var avatarImg: String?
    var recoveryCode: String
    var isCreator: Bool
}

// MARK: - API Responses

struct RegisterResponse: Codable {
    var userId: String
    var name: String
    var avatarEmoji: String
    var avatarColor: String
    var avatarImg: String?
    var recoveryCode: String
    var isCreator: Bool
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
