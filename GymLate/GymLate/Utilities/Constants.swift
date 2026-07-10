import SwiftUI
import UIKit

enum K {
    static let accent      = Color(hex: "#facc15")   // yellow-400
    static let accentLight = Color(hex: "#fde047")   // yellow-300
    static let accentDeep  = Color(hex: "#f59e0b")   // amber-500
    static let accentDark  = Color(hex: "#b45309")   // amber-700
    static let onAccent    = Color(hex: "#422006")   // text on yellow surfaces (white fails contrast)
    static let red         = Color(hex: "#ef4444")
    static let green       = Color(hex: "#22c55e")
    static let gold        = Color(hex: "#f59e0b")   // == accentDeep; status-gold stays the deep end of the accent family
    static let amberText   = Color(light: "#b45309", dark: "#fbbf24")  // readable amber for labels on glass

    // Deployed server URL (Railway)
    static let apiBaseURL  = "https://gym-late-production.up.railway.app"
    static let cornerRadius: CGFloat = 12

    // Avatar options — same lists as the website
    static let avatarEmojis = ["🏋️"]
    static let avatarColors = ["#7c3aed", "#db2777", "#dc2626", "#ea580c", "#ca8a04",
                               "#16a34a", "#0891b2", "#2563eb", "#7e22ce", "#475569"]

    /// UI strings, de/en — mirrors the website's TRANS table.
    /// Language follows the system locale, like `navigator.language` on the web.
    enum L {
        static let de = Locale.preferredLanguages.first?.lowercased().hasPrefix("de") ?? false

        // Landing
        static var appName: String { "GymLate" }
        static var tagline: String { de ? "Die Gym-App für dich und deine Crew: Check-ins, Streaks – und wer zu spät kommt." : "The gym app for you and your crew: check-ins, streaks — and who's late." }
        static var lsFeatStreak: String { de ? "Streak halten" : "Keep a streak" }
        static var lsFeatCheckin: String { de ? "Wer ist spät?" : "Who's late?" }
        static var lsFeatGroup: String { de ? "Mit deiner Crew" : "With your crew" }
        static var create: String { de ? "Neue Gruppe erstellen" : "Create a new group" }
        static var join: String { de ? "Mit Code beitreten" : "Join with a code" }

        // Nav + section labels
        static var navHome: String { "Home" }
        static var navWeek: String { de ? "Woche" : "Week" }
        static var navHistory: String { de ? "Verlauf" : "History" }
        static var navRecap: String { de ? "Rückblick" : "Recap" }
        static var navPeople: String { de ? "Personen" : "People" }
        static var lblWeek: String { de ? "Diese Woche" : "This Week" }
        static var lblHistory: String { de ? "Wochenrückblick" : "Weekly Recap" }
        static var lblPeople: String { de ? "Mitglieder" : "Members" }
        static var pillHint: String { de ? "tippen zum kopieren" : "tap to copy" }

        // Week tab
        static var sCountLbl: String { de ? "Verspätungen" : "Late Arrivals" }
        static var sMinLbl: String { de ? "Min. gesamt" : "Total Mins" }
        static var emptyWeek: String { de ? "Noch niemand zu spät!" : "Nobody was late this week!" }
        static var emptyHistory: String { de ? "Noch keine abgeschlossenen Wochen" : "No completed weeks yet" }
        static var emptyPeople: String { de ? "Noch keine Personen" : "No people added yet" }
        static var skipped: String { de ? "übersprungen" : "skipped" }
        static var minsShort: String { de ? "Min." : "min" }
        static var lateKing: String { de ? "Häufigster Zuspätkommer" : "Most Often Late" }
        static var recapTrendTitle: String { de ? "Verspätungen pro Tag" : "Late min. per day" }
        static var recapBetterWeek: String { de ? "Besser als letzte Woche" : "Better than last week" }
        static var recapSameWeek: String { de ? "Wie letzte Woche" : "Same as last week" }
        static var recapWorseWeek: String { de ? "Schlechter als letzte Woche" : "Worse than last week" }
        static var recapFirstWeek: String { de ? "Erste aufgezeichnete Woche" : "First recorded week" }
        static var recapMostPunctual: String { de ? "Pünktlichste" : "Most Punctual" }
        static var recapMostImproved: String { de ? "Meiste Verbesserung" : "Most Improved" }
        static func recapOnTime(_ n: Int) -> String { de ? "\(n)× pünktlich" : "\(n)× on time" }
        static func recapImprovedBy(_ n: Int) -> String { de ? "−\(n) Min. vs. letzte Woche" : "−\(n) min vs last week" }
        static var allSkippedTitle: String { de ? "Alles übersprungen" : "All skipped" }
        static func timesLate(_ n: Int) -> String { de ? (n == 1 ? "1× zu spät" : "\(n)× zu spät") : (n == 1 ? "1× late" : "\(n)× late") }
        static func weekRange(_ s: String, _ e: String) -> String { "\(fmtShort(s)) – \(fmtShort(e))" }

        // Streak hero + animation
        static func shDays(_ n: Int) -> String { de ? (n == 1 ? "Tag Streak" : "Tage Streak") : "day streak" }
        static var shHintOpen: String { de ? "Jetzt einchecken →" : "Check in now →" }
        static var shHintDone: String { de ? "Heute verlängert!" : "Extended today!" }
        static func saLbl(_ n: Int) -> String { de ? (n == 1 ? "Tag Streak!" : "Tage Streak!") : "day streak!" }
        static var saContinue: String { de ? "Weiter" : "Continue" }

        // Log entry modal
        static var mlTitle: String { de ? "Verspätung eintragen" : "Log Entry" }
        static var mlModeAttend: String { de ? "✓ Ich war da" : "✓ I went" }
        static var mlModeLate: String { de ? "Verspätet" : "Late" }
        static var mlModeSkip: String { de ? "⊘ Skip" : "⊘ Skip" }
        static var mlLblPerson: String { de ? "Person" : "Person" }
        static var mlLblDate: String { de ? "Datum" : "Date" }
        static var mlLblMins: String { de ? "Minuten" : "Minutes" }
        static var mlLblReason: String { de ? "Grund (optional)" : "Reason (optional)" }
        static var noPeople: String { de ? "Erst Personen hinzufügen!" : "Please add people first!" }
        static var cancel: String { de ? "Abbrechen" : "Cancel" }
        static var save: String { de ? "Speichern" : "Save" }
        static var close: String { de ? "Schließen" : "Close" }

        // Entry types
        static var streak: String { "Streak" }
        static var freezes: String { "Freezes" }
        static var late: String { de ? "Verspätet" : "Late" }
        static var attend: String { de ? "Eingecheckt" : "Checked in" }
        static var skip: String { "Skip" }

        // Toasts
        static var toastCopied: String { de ? "Code kopiert! ✓" : "Code copied! ✓" }
        static var toastSaved: String { de ? "Eingetragen! ✓" : "Saved! ✓" }
        static var toastSkipSaved: String { de ? "Skip gespeichert ⊘" : "Skip logged ⊘" }
        static var toastAttendSaved: String { de ? "Eingecheckt ✓" : "Checked in ✓" }
        static var toastProfileSaved: String { de ? "Profil gespeichert ✓" : "Profile saved ✓" }
        static var toastKicked: String { de ? "Mitglied entfernt ✓" : "Member removed ✓" }
        static var toastOnTime: String { de ? "Pünktlich eingecheckt!" : "Checked in on time!" }
        static var toastLate: String { de ? "Verspätet eingecheckt" : "Checked in late" }
        static var toastGymDaysSaved: String { de ? "Gym-Tage gespeichert ✓" : "Gym days saved ✓" }
        static var toastAvailSaved: String { de ? "Verfügbarkeit gespeichert ✓" : "Availability saved ✓" }
        static var toastLocationSaved: String { de ? "Standort gespeichert ✓" : "Location saved ✓" }
        static var toastMemberUpdated: String { de ? "Mitglied aktualisiert ✓" : "Member updated ✓" }
        static var toastQueuedOffline: String { de ? "Offline gespeichert – wird synchronisiert ✓" : "Saved offline – will sync ✓" }

        // Errors
        static var errServer: String { de ? "Serverfehler. Bitte erneut versuchen." : "Server error. Please try again." }
        static var errNotFound: String { de ? "Gruppe nicht gefunden." : "Group not found." }
        static var errNameTaken: String { de ? "Dieser Name ist bereits vergeben." : "This name is already taken." }
        static var errAtLeastOneDay: String { de ? "Mindestens 1 Tag wählen." : "Select at least 1 day." }
        static var errAvailLocked: String { de ? "Bitte warte, bevor du deine Tage erneut änderst." : "Please wait before changing your days again." }
        static var errLocationNotAvailable: String { de ? "Standort nicht verfügbar" : "Location not available" }
        static var errWrongCode: String { de ? "Falscher Recovery Code." : "Wrong recovery code." }

        // Confirm
        static var confirmLeave: String { de ? "Gruppe wirklich verlassen?\n(Deine Daten bleiben auf dem Server gespeichert.)" : "Really leave the group?\n(Your data stays on the server.)" }
        static func pvKickConfirm(_ n: String) -> String { de ? "„\(n)“ wirklich aus der Gruppe entfernen?" : "Really remove \"\(n)\" from the group?" }

        // People / profile
        static var inviteHint: String { de ? "Teile den Code, damit andere der Gruppe beitreten können." : "Share the code so others can join the group." }
        static var inviteBtn: String { de ? "Code teilen" : "Share Code" }
        static var leaveGroup: String { de ? "Gruppe verlassen" : "Leave Group" }
        static var pvRcLbl: String { de ? "Recovery Code (geheim)" : "Recovery Code (secret)" }
        static var pvReveal: String { de ? "anzeigen" : "reveal" }
        static var pvHide: String { de ? "verbergen" : "hide" }
        static var pvEditBtn: String { de ? "Profil bearbeiten" : "Edit Profile" }
        static var pvKickBtn: String { de ? "Aus Gruppe entfernen" : "Remove from group" }
        static var pvCreatorBadge: String { de ? "Gruppenersteller" : "Group Creator" }
        static var pvStatCount: String { de ? "Verspätungen" : "Late arrivals" }
        static var pvStatMins: String { de ? "Min. gesamt" : "Total mins" }
        static var pvGymDaysLbl: String { de ? "Geht ins Gym:" : "Goes to gym:" }

        // Edit profile
        static var epTitle: String { de ? "Profil bearbeiten" : "Edit Profile" }
        static var epNameLbl: String { de ? "Name" : "Name" }
        static var epEmojiLbl: String { "Avatar" }
        static var epColorLbl: String { de ? "Farbe" : "Color" }
        static var uploadPhoto: String { de ? "Foto hochladen" : "Upload photo" }
        static var removePhoto: String { de ? "✕ Foto entfernen" : "✕ Remove photo" }
        static var nsfwError: String { de ? "Dieses Bild ist nicht erlaubt." : "This image is not allowed." }

        // Group switcher
        static var mgsTitle: String { de ? "Meine Gruppen" : "My Groups" }
        static var mgsJoin: String { de ? "Einer anderen Gruppe beitreten" : "Join another group" }
        static var mgsCreate: String { de ? "Neue Gruppe erstellen" : "Create new group" }
        static var mgsActive: String { de ? "Aktiv" : "Active" }
        static var mgsSwitch: String { de ? "Wechseln" : "Switch" }

        // Settings
        static var msetTitle: String { de ? "Einstellungen" : "Settings" }
        static var msetGymDaysLbl: String { de ? "Gym-Tage der Gruppe" : "Group gym days" }
        static var msetAvailLbl: String { de ? "Meine verfügbaren Tage" : "My available days" }
        static var msetGymSave: String { de ? "Gym-Tage speichern" : "Save gym days" }
        static var msetLocationLbl: String { de ? "Gym-Standort" : "Gym Location" }
        static var msetRadiusLbl: String { de ? "Radius" : "Radius" }
        static var msetLocateBtn: String { de ? "Meinen Standort nutzen" : "Use my location" }
        static var msetLocationSave: String { de ? "Standort speichern" : "Save location" }
        static var msetGeoLbl: String { de ? "Automatischer Check-in" : "Auto Check-in" }
        static var msetGeoToggleLbl: String { de ? "Geo-Check aktiviert" : "Geo check-in enabled" }
        static var msetGeoTestBtn: String { de ? "Standort testen" : "Test location" }
        static var msetGeoNoLoc: String { de ? "Kein Gym-Standort gesetzt." : "No gym location set." }
        static var msetFixedtimeLbl: String { de ? "Feste Check-in-Zeit" : "Fixed check-in time" }
        static var msetFixedtimeToggleLbl: String { de ? "Feste Uhrzeit aktiviert" : "Fixed time enabled" }
        static var toastFixedCheckinOn: String { de ? "Feste Check-in-Zeit aktiviert" : "Fixed check-in time enabled" }
        static var toastFixedCheckinOff: String { de ? "Feste Check-in-Zeit deaktiviert" : "Fixed check-in time disabled" }

        // Notifications
        static var msetNotifLbl: String { de ? "Benachrichtigungen" : "Notifications" }
        static var msetNotifRemindersLbl: String { de ? "Gym-Erinnerung" : "Gym day reminder" }
        static var msetReminderTimeLbl: String { de ? "Erinnerungszeit" : "Reminder time" }
        static var msetNotifStreakLbl: String { de ? "Streak in Gefahr" : "Streak at risk" }
        static var msetNotifActivityLbl: String { de ? "Gruppen-Aktivität" : "Group activity" }
        static var msetQuietLbl: String { de ? "Ruhezeiten" : "Quiet hours" }
        static var msetQuietStartLbl: String { de ? "Von" : "From" }
        static var msetQuietEndLbl: String { de ? "Bis" : "Until" }
        static var msetNotifMembersLbl: String { de ? "Benachrichtigen bei" : "Notify me when" }
        static var toastNotifSaved: String { de ? "Benachrichtigungen gespeichert ✓" : "Notifications saved ✓" }

        // Fixed check-in time hero
        static var checkinTimeChipLbl: String { de ? "Check-in um" : "Check in at" }
        static var checkinTimeChangeBtn: String { de ? "Ändern" : "Change" }
        static func dhTimeWindowHint(_ t: String) -> String { de ? "Check-in-Fenster: \(t) ± 10 Min." : "Check-in window: \(t) ± 10 min." }

        // Late / streak animations + chest
        static var laTitle: String { de ? "Verspätet!" : "Late!" }
        static func laSub(_ m: Int) -> String { de ? "\(m) Min. nach der festen Uhrzeit eingecheckt" : "Checked in \(m) min. after the fixed time" }
        static var chestGotFreeze: String { de ? "❄️ Freeze erhalten!" : "❄️ Freeze received!" }
        static var chestSub: String { de ? "Du hast eine Streak-Schutzpflanze" : "Your streak is protected for one miss" }
        static var chestNoReward: String { de ? "Kein Gewinn diesmal" : "No reward this time" }
        static var chestOk: String { de ? "Cool!" : "Nice!" }
        static func chestStreak(_ n: Int) -> String { de ? "Dein Streak: 🔥 \(n)" : "Your streak: 🔥 \(n)" }

        // Admin
        static var maTitle: String { de ? "Admin-Login" : "Admin Login" }
        static var maLbl: String { de ? "Passwort" : "Password" }
        static var maSubmit: String { de ? "Einloggen" : "Login" }
        static var maError: String { de ? "Falsches Passwort" : "Wrong password" }
        static var admTitle: String { de ? "Admin-Modus" : "Admin Mode" }
        static var admAdd: String { de ? "Testdaten letzte Woche" : "Create last week's test data" }
        static var admDel: String { de ? "Testdaten löschen" : "Delete test data" }
        static var admWeekOn: String { de ? "Aktuelle Woche zeigen" : "Show current week" }
        static var admWeekOff: String { de ? "Aktuelle Woche ausblenden" : "Hide current week" }
        static var admReplay: String { de ? "Wrapped nochmal" : "Replay Wrapped" }
        static var admExit: String { de ? "Admin verlassen" : "Exit admin mode" }
        static var admForceHype: String { de ? "Hype-Animation testen" : "Test hype animation" }
        static var admForceGeo: String { de ? "Geo-Prompt testen" : "Test geo prompt" }
        static var admClearFlags: String { de ? "Tagesflags zurücksetzen" : "Clear today's flags" }
        static var admSectionData: String { de ? "Testdaten" : "Test data" }
        static var admSectionCeremonies: String { de ? "Animationen" : "Ceremonies" }
        static var admSectionNotif: String { de ? "Benachrichtigungen (10s)" : "Notifications (10s delay)" }
        static var admTestReminder: String { de ? "Erinnerung" : "Reminder" }
        static var admTestStreak: String { de ? "Streak-Risiko" : "Streak risk" }
        static var admTestActivity: String { de ? "Aktivität" : "Activity" }
        static var admTestAll: String { de ? "Alle senden" : "Send all" }
        static var toastTestScheduled: String { de ? "Wird in 10s gesendet…" : "Sending in 10s…" }
        static var toastAdmIn: String { de ? "Admin-Modus aktiviert" : "Admin mode activated" }
        static var toastAdmOut: String { de ? "Admin-Modus beendet" : "Admin mode exited" }
        static var toastAdded: String { de ? "Testdaten erstellt ✓" : "Test data created ✓" }
        static var auDaysLbl: String { de ? "Verfügbare Tage" : "Available days" }
        static func auTitle(_ n: String) -> String { de ? "\(n) bearbeiten" : "Edit \(n)" }
        static var eeTitle: String { de ? "Eintrag bearbeiten" : "Edit Entry" }

        // Notification bubbles (opening-sequence prompts)
        static var bubbleWrappedTitle: String { de ? "Wöchentlicher Rückblick 🎉" : "Weekly Recap 🎉" }
        static var bubbleWrappedSub: String { de ? "Tippe um den Rückblick zu sehen" : "Tap to watch the recap" }
        static var bubbleHypeTitle: String { de ? "Heute ist Gym-Tag 💪" : "It's gym day 💪" }
        static var bubbleHypeSub: String { de ? "Los geht's!" : "Let's go!" }
        static var bubbleGeoTitle: String { de ? "Du bist in der Nähe 📍" : "You're nearby 📍" }
        static var bubbleGeoSub: String { de ? "Jetzt einchecken?" : "Check in now?" }

        // Replay hints (shown after bubble dismiss)
        static var replayHintRecap: String { de ? "Rückblick unter Recap ansehen ›" : "Rewatch recap under Recap ›" }
        static var replayHintCheckin: String { de ? "Über den Check-in-Button einchecken ›" : "Check in via the check-in button ›" }

        // Recap replay button
        static var recapReplayBtn: String { de ? "▶ Wöchentlicher Rückblick" : "▶ Weekly Recap" }

        // Admin calendar editing
        static var admCalAddEntry: String { de ? "+ Eintrag hinzufügen" : "+ Add entry" }
        static var admCalEditEntry: String { de ? "Eintrag bearbeiten" : "Edit entry" }
        static var admCalDeleteEntry: String { de ? "Löschen" : "Delete" }
        static var toastEntryAdded: String { de ? "Eintrag hinzugefügt ✓" : "Entry added ✓" }
        static var toastEntryEdited: String { de ? "Eintrag aktualisiert ✓" : "Entry updated ✓" }
        static var toastEntryDeleted: String { de ? "Eintrag gelöscht ✓" : "Entry deleted ✓" }

        // Notification primer (one-time onboarding overlay)
        static var notifPrimerTitle: String { de ? "Benachrichtigungen" : "Stay in the loop" }
        static var notifPrimerBody: String { de ? "GymLate erinnert dich an Gym-Tage und warnt dich, wenn dein Streak in Gefahr ist." : "GymLate can remind you on gym days and alert you when your streak is at risk." }
        static var notifPrimerEnable: String { de ? "Benachrichtigungen erlauben" : "Enable notifications" }
        static var notifPrimerLater: String { de ? "Später" : "Not now" }

        // Misc
        static var dayNames: [String] { de ? ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"] : ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"] }
        static var reasons: [(id: String, label: String)] {
            de ? [("rest", "Ruhetag"), ("sick", "Krank"), ("injured", "Verletzt"), ("no_time", "Keine Zeit"), ("deload", "Deload")]
               : [("rest", "Rest day"), ("sick", "Sick"), ("injured", "Injured"), ("no_time", "No time"), ("deload", "Deload")]
        }
        static func reasonLabel(_ r: String?) -> String? {
            guard let r, !r.isEmpty else { return nil }
            return reasons.first { $0.id == r }?.label
        }
        static func streakDaysWord(_ n: Int) -> String { de ? (n == 1 ? "Tag" : "Tage") : (n == 1 ? "day" : "days") }
    }
}

extension Color {
    /// Adaptive color that switches hex values with the system appearance.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { tc in
            UIColor(Color(hex: tc.userInterfaceStyle == .dark ? dark : light))
        })
    }

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        let r = Double((val >> 16) & 0xff) / 255
        let g = Double((val >> 8) & 0xff) / 255
        let b = Double(val & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}
