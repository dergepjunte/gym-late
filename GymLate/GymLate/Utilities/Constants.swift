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

    // German UI strings
    enum L {
        static let appName       = "GymLate"
        static let tagline       = "Die Gym-App für dich und deine Crew: Check-ins, Streaks – und wer zu spät kommt."
        static let create        = "Neue Gruppe erstellen"
        static let join          = "Mit Code beitreten"
        static let navWeek       = "Woche"
        static let navHistory    = "Verlauf"
        static let navRecap      = "Rückblick"
        static let navPeople     = "Personen"
        static let streak        = "Streak"
        static let freezes       = "Freezes"
        static let late          = "Verspätet"
        static let attend        = "Eingecheckt"
        static let skip          = "Skip"
        static let errServer     = "Serverfehler. Bitte erneut versuchen."
        static let errNotFound   = "Gruppe nicht gefunden."
        static let toastCopied   = "Code kopiert! ✓"
        static let toastSaved    = "Eingetragen! ✓"
        static let confirmLeave  = "Gruppe wirklich verlassen?\n(Deine Daten bleiben auf dem Server gespeichert.)"
        static let dayNames      = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        static let reasons: [(id: String, label: String)] = [
            ("rest", "Ruhetag"), ("sick", "Krank"), ("injured", "Verletzt"),
            ("no_time", "Keine Zeit"), ("deload", "Deload"),
        ]
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
