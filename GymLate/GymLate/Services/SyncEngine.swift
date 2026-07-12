import Foundation

/// Routes writes online-first with an offline fallback queue, and replays the
/// queue once the server is reachable. Streaks/freezes/chests are computed
/// server-side, so after any successful replay the caller must refresh from
/// the server as the source of truth.
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var pendingCount = 0
    @Published private(set) var isReplaying = false

    /// Message for the UI when replayed mutations were rejected by the server.
    @Published var syncErrorMessage: String?

    private let outbox = OutboxStore.shared
    private let api = APIClient.shared

    private init() {
        pendingCount = outbox.count
    }

    enum SubmitResult {
        case synced(CreateEntryResponse)
        case queued(localEntry: Entry)
    }

    // MARK: - Submit (online first, queue on transport failure)

    func submitLogEntry(groupId: String, person: String, date: String,
                        type: String, mins: Int?, reason: String?) async throws -> SubmitResult {
        do {
            let resp = try await api.logEntry(groupId: groupId, person: person, date: date,
                                              type: type, mins: mins, reason: reason)
            return .synced(resp)
        } catch where error.isNetworkError {
            let localId = "local-\(UUID().uuidString)"
            enqueue(groupId: groupId, payload: .logEntry(
                person: person, date: date, type: type,
                mins: mins, reason: reason, localEntryId: localId))
            let entry = Entry(id: localId, person: person, date: date,
                              mins: mins ?? 0,
                              ts: Int(Date().timeIntervalSince1970 * 1000),
                              type: type, reason: reason)
            return .queued(localEntry: entry)
        }
    }

    /// Returns true when synced immediately, false when queued for later.
    /// `accountToken` (when the profile is account-linked, i.e. `recoveryCode`
    /// is nil) is used ONLY for the immediate online attempt — it is
    /// deliberately NOT persisted into the offline outbox, so the on-disk
    /// `PendingMutation.Payload` shape (and any already-queued mutations from
    /// before this feature existed) stay untouched. If this specific write
    /// happens to go offline for an already-migrated user, it's queued keyed
    /// on `recoveryCode` (empty for account-linked profiles) and will need a
    /// retry once online rather than replaying automatically — a narrow,
    /// acceptable gap given how rare "offline + freshly migrated" is.
    func submitPatchUser(groupId: String, userId: String, name: String? = nil,
                         avatarEmoji: String? = nil, avatarColor: String? = nil,
                         avatarImg: String? = nil, availDays: String? = nil,
                         recoveryCode: String?, accountToken: String? = nil) async throws -> Bool {
        do {
            try await api.patchUser(groupId: groupId, userId: userId, name: name,
                                    avatarEmoji: avatarEmoji, avatarColor: avatarColor,
                                    avatarImg: avatarImg, availDays: availDays,
                                    recoveryCode: recoveryCode, accountToken: accountToken)
            return true
        } catch where error.isNetworkError {
            enqueue(groupId: groupId, payload: .patchUser(
                userId: userId, name: name, avatarEmoji: avatarEmoji,
                avatarColor: avatarColor, avatarImg: avatarImg,
                availDays: availDays, recoveryCode: recoveryCode ?? ""))
            return false
        }
    }

    func submitPatchGroup(groupId: String, gymDays: String? = nil,
                          fixedCheckinEnabled: Bool? = nil,
                          creatorUserId: String, creatorRecoveryCode: String?,
                          accountToken: String? = nil) async throws -> Bool {
        do {
            try await api.patchGroup(id: groupId, gymDays: gymDays,
                                     fixedCheckinEnabled: fixedCheckinEnabled,
                                     creatorUserId: creatorUserId,
                                     creatorRecoveryCode: creatorRecoveryCode,
                                     accountToken: accountToken)
            return true
        } catch where error.isNetworkError {
            enqueue(groupId: groupId, payload: .patchGroup(
                gymDays: gymDays, fixedCheckinEnabled: fixedCheckinEnabled,
                creatorUserId: creatorUserId, creatorRecoveryCode: creatorRecoveryCode ?? ""))
            return false
        }
    }

    func submitDeleteEntry(groupId: String, entryId: String,
                           actorUserId: String?, actorRecoveryCode: String?) async throws -> Bool {
        do {
            try await api.deleteEntry(groupId: groupId, entryId: entryId,
                                      actorUserId: actorUserId,
                                      actorRecoveryCode: actorRecoveryCode)
            return true
        } catch where error.isNetworkError {
            enqueue(groupId: groupId, payload: .deleteEntry(
                entryId: entryId, actorUserId: actorUserId,
                actorRecoveryCode: actorRecoveryCode))
            return false
        }
    }

    // MARK: - Replay

    /// Replays the outbox FIFO. Stops on transport errors (still offline);
    /// drops mutations the server rejects (invalid input won't get better).
    /// Returns true if at least one mutation reached the server.
    func replayAll() async -> Bool {
        guard !isReplaying, outbox.count > 0 else { return false }
        isReplaying = true
        defer {
            isReplaying = false
            pendingCount = outbox.count
        }

        var replayedAny = false
        var rejectedCount = 0

        for mutation in outbox.all {
            outbox.markAttempt(id: mutation.id)
            do {
                try await replay(mutation)
                outbox.remove(id: mutation.id)
                replayedAny = true
            } catch where error.isNetworkError {
                break
            } catch {
                outbox.remove(id: mutation.id)
                rejectedCount += 1
            }
        }

        if rejectedCount > 0 {
            syncErrorMessage = rejectedCount == 1
                ? "1 Eintrag konnte nicht synchronisiert werden."
                : "\(rejectedCount) Einträge konnten nicht synchronisiert werden."
        }
        return replayedAny
    }

    private func replay(_ m: PendingMutation) async throws {
        switch m.payload {
        case .logEntry(let person, let date, let type, let mins, let reason, _):
            _ = try await api.logEntry(groupId: m.groupId, person: person, date: date,
                                       type: type, mins: mins, reason: reason)
        case .deleteEntry(let entryId, let actorUserId, let actorRecoveryCode):
            try await api.deleteEntry(groupId: m.groupId, entryId: entryId,
                                      actorUserId: actorUserId,
                                      actorRecoveryCode: actorRecoveryCode)
        case .patchUser(let userId, let name, let emoji, let color, let img,
                        let availDays, let recoveryCode):
            try await api.patchUser(groupId: m.groupId, userId: userId, name: name,
                                    avatarEmoji: emoji, avatarColor: color, avatarImg: img,
                                    availDays: availDays, recoveryCode: recoveryCode)
        case .patchGroup(let gymDays, let fixedCheckin, let creatorUserId, let creatorRecoveryCode):
            try await api.patchGroup(id: m.groupId, gymDays: gymDays,
                                     fixedCheckinEnabled: fixedCheckin,
                                     creatorUserId: creatorUserId,
                                     creatorRecoveryCode: creatorRecoveryCode)
        }
    }

    // MARK: - Optimistic overlay

    /// Overlays queued logEntry mutations onto server/cache data so optimistic
    /// entries stay visible across refreshes until they are replayed.
    func applyPending(to data: GroupData) -> GroupData {
        var result = data
        for m in OutboxStore.shared.pending(for: data.id) {
            if case .logEntry(let person, let date, let type, let mins, let reason,
                              let localId) = m.payload {
                guard !result.entries.contains(where: { $0.id == localId }) else { continue }
                result.entries.insert(Entry(
                    id: localId, person: person, date: date, mins: mins ?? 0,
                    ts: Int(m.createdAt.timeIntervalSince1970 * 1000),
                    type: type, reason: reason), at: 0)
            }
        }
        return result
    }

    private func enqueue(groupId: String, payload: PendingMutation.Payload) {
        outbox.enqueue(PendingMutation(id: UUID(), groupId: groupId,
                                       createdAt: Date(), attempts: 0, payload: payload))
        pendingCount = outbox.count
    }

    func dropPending(for groupId: String) {
        OutboxStore.shared.removeAll(for: groupId)
        pendingCount = OutboxStore.shared.count
    }
}
