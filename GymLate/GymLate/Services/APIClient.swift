import Foundation

enum APIError: LocalizedError {
    case notFound
    case unauthorized
    case nameTaken
    case wrongCode
    case server(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Gruppe nicht gefunden. Code prüfen!"
        case .unauthorized: return "Nicht autorisiert."
        case .nameTaken: return "Dieser Name ist bereits vergeben."
        case .wrongCode: return "Falscher Recovery Code."
        case .server(let code): return "Serverfehler: \(code)"
        case .network(let e): return e.localizedDescription
        }
    }

    /// True for transport failures (offline, timeout, DNS) that are worth
    /// retrying later — as opposed to server verdicts, which are final.
    var isNetworkError: Bool {
        if case .network = self { return true }
        return false
    }
}

extension Error {
    var isNetworkError: Bool {
        (self as? APIError)?.isNetworkError ?? (self is URLError)
    }
}

final class APIClient {
    static let shared = APIClient()
    // Single source of truth: K.apiBaseURL in Constants.swift
    var baseURL: String = K.apiBaseURL

    private init() {}

    private func request<T: Decodable>(
        _ method: String, path: String, body: Encodable? = nil
    ) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server("no_response")
        }
        if http.statusCode == 404 { throw APIError.notFound }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode == 409 { throw APIError.nameTaken }
        if http.statusCode >= 400 {
            if let errBody = try? JSONDecoder().decode([String: String].self, from: data),
               let code = errBody["error"] {
                throw APIError.server(code)
            }
            throw APIError.server("status_\(http.statusCode)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Groups

    func createGroup(name: String, gymDays: String) async throws -> GroupInfo {
        struct Body: Encodable { let name: String; let gym_days: String }
        struct Resp: Decodable { let id: String; let code: String; let name: String }
        let r: Resp = try await request("POST", path: "/api/groups", body: Body(name: name, gym_days: gymDays))
        return GroupInfo(id: r.id, code: r.code, name: r.name)
    }

    func joinGroup(code: String) async throws -> GroupInfo {
        struct Body: Encodable { let code: String }
        struct Resp: Decodable { let id: String; let code: String; let name: String }
        let r: Resp = try await request("POST", path: "/api/groups/join", body: Body(code: code))
        return GroupInfo(id: r.id, code: r.code, name: r.name)
    }

    func getGroup(id: String) async throws -> GroupData {
        let data: GroupData = try await request("GET", path: "/api/groups/\(id)")
        return data
    }

    func patchGroup(id: String, gymDays: String? = nil, gymLat: Double? = nil, gymLng: Double? = nil,
                    gymRadius: Int? = nil, fixedCheckinEnabled: Bool? = nil,
                    creatorUserId: String? = nil, creatorRecoveryCode: String? = nil,
                    adminPassword: String? = nil) async throws {
        struct Body: Encodable {
            var gym_days: String?; var gym_lat: Double?; var gym_lng: Double?; var gym_radius: Int?
            var fixed_checkin_enabled: Bool?; var creatorUserId: String?; var creatorRecoveryCode: String?
            var adminPassword: String?
        }
        let _: OkResponse = try await request("PATCH", path: "/api/groups/\(id)", body: Body(
            gym_days: gymDays, gym_lat: gymLat, gym_lng: gymLng, gym_radius: gymRadius,
            fixed_checkin_enabled: fixedCheckinEnabled,
            creatorUserId: creatorUserId, creatorRecoveryCode: creatorRecoveryCode,
            adminPassword: adminPassword))
    }

    // MARK: - Users

    func registerUser(groupId: String, name: String, avatarEmoji: String, avatarColor: String,
                      avatarImg: String? = nil) async throws -> RegisterResponse {
        struct Body: Encodable {
            let name: String; let avatarEmoji: String; let avatarColor: String; let avatarImg: String?
        }
        return try await request("POST", path: "/api/groups/\(groupId)/users",
                                 body: Body(name: name, avatarEmoji: avatarEmoji,
                                           avatarColor: avatarColor, avatarImg: avatarImg))
    }

    func loginUser(groupId: String, name: String, recoveryCode: String) async throws -> LoginResponse {
        struct Body: Encodable { let name: String; let recoveryCode: String }
        return try await request("POST", path: "/api/groups/\(groupId)/users/login",
                                 body: Body(name: name, recoveryCode: recoveryCode))
    }

    func patchUser(groupId: String, userId: String, name: String? = nil,
                   avatarEmoji: String? = nil, avatarColor: String? = nil, avatarImg: String? = nil,
                   availDays: String? = nil, recoveryCode: String? = nil,
                   streak: Int? = nil, freezes: Int? = nil, adminPassword: String? = nil) async throws {
        struct Body: Encodable {
            var name: String?; var avatarEmoji: String?; var avatarColor: String?; var avatarImg: String?
            var avail_days: String?; var recoveryCode: String?
            var streak: Int?; var freezes: Int?; var adminPassword: String?
        }
        let _: OkResponse = try await request("PATCH",
            path: "/api/groups/\(groupId)/users/\(userId)",
            body: Body(name: name, avatarEmoji: avatarEmoji, avatarColor: avatarColor,
                      avatarImg: avatarImg, avail_days: availDays, recoveryCode: recoveryCode,
                      streak: streak, freezes: freezes, adminPassword: adminPassword))
    }

    func deleteUser(groupId: String, userId: String, actorUserId: String? = nil,
                    actorRecoveryCode: String? = nil, adminPassword: String? = nil) async throws {
        struct Body: Encodable {
            var actorUserId: String?; var actorRecoveryCode: String?; var adminPassword: String?
        }
        let _: OkResponse = try await request("DELETE",
            path: "/api/groups/\(groupId)/users/\(userId)",
            body: Body(actorUserId: actorUserId, actorRecoveryCode: actorRecoveryCode,
                      adminPassword: adminPassword))
    }

    // MARK: - Entries

    func logEntry(groupId: String, person: String, date: String, type: String,
                  mins: Int? = nil, reason: String? = nil) async throws -> CreateEntryResponse {
        struct Body: Encodable {
            let person: String; let date: String; let type: String; let mins: Int?; let reason: String?
        }
        return try await request("POST", path: "/api/groups/\(groupId)/entries",
                                 body: Body(person: person, date: date, type: type, mins: mins, reason: reason))
    }

    func deleteEntry(groupId: String, entryId: String, actorUserId: String? = nil,
                     actorRecoveryCode: String? = nil, adminPassword: String? = nil) async throws {
        struct Body: Encodable {
            var actorUserId: String?; var actorRecoveryCode: String?; var adminPassword: String?
        }
        let _: OkResponse = try await request("DELETE",
            path: "/api/groups/\(groupId)/entries/\(entryId)",
            body: Body(actorUserId: actorUserId, actorRecoveryCode: actorRecoveryCode,
                      adminPassword: adminPassword))
    }

    func patchEntry(groupId: String, entryId: String, type: String, date: String,
                    mins: Int? = nil, reason: String? = nil, adminPassword: String) async throws {
        struct Body: Encodable {
            let type: String; let date: String; let mins: Int?; let reason: String?
            let adminPassword: String
        }
        let _: OkResponse = try await request("PATCH",
            path: "/api/groups/\(groupId)/entries/\(entryId)",
            body: Body(type: type, date: date, mins: mins, reason: reason,
                      adminPassword: adminPassword))
    }

    // MARK: - Fixed check-in time (beta)

    func setCheckinTime(groupId: String, date: String, time: String) async throws {
        struct Body: Encodable { let date: String; let time: String }
        struct Resp: Decodable { let ok: Bool }
        let _: Resp = try await request("POST", path: "/api/groups/\(groupId)/checkin-time",
                                        body: Body(date: date, time: time))
    }

    // MARK: - Admin

    func createTestGroup(adminPassword: String) async throws -> (group: GroupInfo, user: RegisterResponse) {
        struct Body: Encodable { let adminPassword: String }
        struct Resp: Decodable { let group: GroupInfo; let user: RegisterResponse }
        let r: Resp = try await request("POST", path: "/api/test-group",
                                        body: Body(adminPassword: adminPassword))
        return (r.group, r.user)
    }

    func verifyAdmin(password: String) async throws -> Bool {
        struct Body: Encodable { let adminPassword: String }
        struct Resp: Decodable { let ok: Bool }
        do {
            let r: Resp = try await request("POST", path: "/api/admin/verify",
                                            body: Body(adminPassword: password))
            return r.ok
        } catch {
            return false
        }
    }
}
