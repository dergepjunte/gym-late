import SwiftUI

extension AppState {
    // MARK: - Streak info & check-in ceremony (website parity)

    /// Website `myStreakInfo()`: my streak plus whether I already extended it today.
    func myStreakInfo() -> (streak: Int, extendedToday: Bool)? {
        guard let profile = userProfile,
              let me = groupData?.people.first(where: { $0.id == profile.userId }) else { return nil }
        let today = dateYMD(Date())
        let extended = (groupData?.entries ?? []).contains {
            $0.person == me.name && $0.date == today && ($0.type == "attend" || $0.type == "late")
        }
        return (me.streak, extended)
    }

    /// Website `computeCheckinLateness()`: ±10-minute window around the fixed
    /// check-in time; nil when the beta feature isn't active for today.
    func computeCheckinLateness() -> (isLate: Bool, minsOff: Int)? {
        guard let data = groupData, data.fixedCheckinEnabled,
              data.checkinTimeDate == dateYMD(Date()),
              let t = data.checkinTime else { return nil }
        let parts = t.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let diff = (now.hour! * 60 + now.minute!) - (parts[0] * 60 + parts[1])
        return (abs(diff) > 10, abs(diff))
    }

    /// Website `finish()` chain after logging a check-in: late-anim → streak-anim
    /// → chest → toast, matching ml-save / submitSelfAttendEntry.
    func runCheckinCeremony(chest: ChestResult?, wasExtended: Bool,
                            lateness: (isLate: Bool, minsOff: Int)?,
                            toast: @escaping (String) -> Void) {
        let info = myStreakInfo()
        let finish = { [weak self] in
            guard let self else { return }
            if let info, !wasExtended {
                if let chest { self.afterStreakAnim = { self.chestResult = chest } }
                self.streakAnimStreak = info.streak
            } else {
                if let chest { self.chestResult = chest }
                if let lateness {
                    toast(lateness.isLate ? K.L.toastLate : K.L.toastOnTime)
                } else {
                    toast(K.L.toastAttendSaved)
                }
            }
        }
        if let lateness, lateness.isLate {
            afterLateAnim = finish
            lateAnimMins = lateness.minsOff
        } else {
            finish()
        }
    }
}
