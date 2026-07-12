import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private override init() { super.init() }

    // MARK: - Permission + APNs token registration

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus != .denied else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        } catch {}
    }

    func registerAPNsToken(_ tokenData: Data, groupId: String, userId: String,
                           recoveryCode: String?, accountToken: String? = nil) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await APIClient.shared.registerAPNsToken(
                token: token, groupId: groupId, userId: userId,
                recoveryCode: recoveryCode, accountToken: accountToken)
        }
    }

    // MARK: - Local notification scheduling

    /// Schedules weekly recurring gym day reminders. Call after any settings change.
    func scheduleReminders(gymDays: String, availDays: String?, reminderTime: String) {
        let center = UNUserNotificationCenter.current()
        // Cancel existing reminders
        center.removePendingNotificationRequests(withIdentifiers:
            (0..<7).map { "gymlate.reminder.\($0)" })

        guard LocalStore.shared.notifReminders else { return }

        let parts0 = reminderTime.split(separator: ":").map(String.init)
        guard parts0.count == 2, let hour = Int(parts0[0]), let minute = Int(parts0[1]) else { return }

        let mask = effectiveDayMask(gymDays: gymDays, availDays: availDays)
        let content = UNMutableNotificationContent()
        content.title = "💪 Gym day!"
        content.body = "Don't forget to check in today"
        content.sound = .default

        // Mon=2…Sun=1 in Calendar.weekday (1=Sun, 2=Mon)
        for i in 0..<7 where Array(mask)[i] == "1" {
            var comps = DateComponents()
            comps.weekday = i == 6 ? 1 : i + 2  // Mon=2, Tue=3, …, Sun=1
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(identifier: "gymlate.reminder.\(i)", content: content, trigger: trigger)
            center.add(req)
        }
    }

    /// Schedules a streak-at-risk notification for today that fires 1h before quiet end (default 21:00).
    func scheduleStreakRisk(quietStart: String) {
        guard LocalStore.shared.notifStreak else { return }
        cancelStreakRiskToday()

        let riskTime = subtractOneHour(quietStart)
        let parts1 = riskTime.split(separator: ":").map(String.init)
        guard parts1.count == 2, let hour = Int(parts1[0]), let minute = Int(parts1[1]) else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak at risk!"
        content.body = "Check in today to keep your streak alive"
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour; comps.minute = minute
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.year = today.year; comps.month = today.month; comps.day = today.day

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "gymlate.streak_risk.\(dateYMD(Date()))"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    /// Call after a successful check-in to cancel today's streak-at-risk notification.
    func cancelStreakRiskToday() {
        let id = "gymlate.streak_risk.\(dateYMD(Date()))"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Test notifications (admin only)

    /// Fires a test notification after a 10-second delay, bypassing the user's
    /// notifReminders/notifStreak guards so it always delivers.
    func sendTestNotification(type: String) async {
        await requestPermission()
        let pairs: [(String, String, String)]
        switch type {
        case "reminder":
            pairs = [("💪 Gym day!", "Don't forget to check in today", "reminder")]
        case "streak":
            pairs = [("🔥 Streak at risk!", "Check in today to keep your streak alive", "streak")]
        case "activity":
            pairs = [("GymLate", "Someone just checked in 💪", "activity")]
        default: // "all"
            pairs = [
                ("💪 Gym day!", "Don't forget to check in today", "reminder"),
                ("🔥 Streak at risk!", "Check in today to keep your streak alive", "streak"),
                ("GymLate", "Someone just checked in 💪", "activity"),
            ]
        }
        for (title, body, tag) in pairs {
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            let id = "gymlate.test.\(tag).\(UUID().uuidString)"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(req)
        }
    }

    // MARK: - Helpers

    private func effectiveDayMask(gymDays: String, availDays: String?) -> String {
        guard gymDays.count == 7 else { return String(repeating: "0", count: 7) }
        guard let avail = availDays, avail.count == 7 else { return gymDays }
        return String(zip(gymDays, avail).map { $0 == "1" && $1 == "1" ? "1" : "0" })
    }

    private func subtractOneHour(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":").map { Int($0) ?? 0 }
        guard parts.count == 2 else { return "21:00" }
        let h = (parts[0] - 1 + 24) % 24
        return String(format: "%02d:%02d", h, parts[1])
    }
}
