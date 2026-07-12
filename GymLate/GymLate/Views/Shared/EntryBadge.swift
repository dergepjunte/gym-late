import SwiftUI

/// Type badge shared with the week list — ✓ / "N Min." / ⊘ reason, like the web badges.
struct EntryBadge: View {
    let entry: Entry

    var body: some View {
        switch entry.type {
        case "attend":
            Text("✓")
                .font(Theme.body(13, .bold)).foregroundColor(K.green)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(K.green.opacity(0.14)))
        case "skip":
            let skipLabel = (entry.auto == true) ? K.L.noShow : (K.L.reasonLabel(entry.reason) ?? K.L.skipped)
            Text("⊘ \(skipLabel)")
                .font(Theme.body(12, .bold)).foregroundColor(K.gold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(K.gold.opacity(0.14)))
        default:
            Text("\(entry.mins) \(K.L.minsShort)")
                .font(Theme.body(13, .bold)).foregroundColor(K.red)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(K.red.opacity(0.14)))
        }
    }
}
