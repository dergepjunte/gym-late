import SwiftUI

/// Type badge shared with the week list — ✓ / "N Min." / ⊘ reason, like the web badges.
/// v0.3: stencil tags (squared, condensed caps) instead of soft pills.
struct EntryBadge: View {
    let entry: Entry

    var body: some View {
        switch entry.type {
        case "attend":
            tag(Text(Image(systemName: "checkmark")) + Text(K.L.de ? " DA" : " IN"), color: K.green)
        case "skip":
            let skipLabel = (entry.auto == true) ? K.L.noShow : (K.L.reasonLabel(entry.reason) ?? K.L.skipped)
            tag(Text("⊘ \(skipLabel)"), color: K.gold)
        default:
            tag(Text("+\(entry.mins) \(K.L.minsShort)"), color: K.red)
        }
    }

    private func tag(_ text: Text, color: Color) -> some View {
        text
            .font(.system(size: 13, weight: .heavy).width(.condensed))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundColor(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(color.opacity(0.13)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(color.opacity(0.45), lineWidth: 1))
    }
}
