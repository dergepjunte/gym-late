import SwiftUI

struct WeekView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showLogEntry: Bool
    @Binding var toast: String?

    private var weekEntries: [Entry] {
        appState.groupData?.entriesThisWeek() ?? []
    }

    private var lateEntries: [Entry] {
        weekEntries.filter { $0.type == "late" }
    }

    private var me: Person? {
        guard let profile = appState.userProfile,
              let data = appState.groupData else { return nil }
        return data.people.first { $0.id == profile.userId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // My streak card
                if let me = me {
                    StreakCard(person: me)
                }

                // Log button
                Button {
                    showLogEntry = true
                    haptic(.medium)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill").font(.title2)
                        Text("Check-in / Verspätung eintragen")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(K.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: Theme.accentGradient,
                                      startPoint: .leading, endPoint: .trailing)
                        .cornerRadius(18)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(
                                stops: [.init(color: .white.opacity(0.35), location: 0),
                                        .init(color: .clear, location: 0.45)],
                                startPoint: .topLeading, endPoint: .bottom))
                            .allowsHitTesting(false)
                    )
                }
                .padding(.horizontal, 16)

                // This week's header
                HStack {
                    Text("Diese Woche")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Text("\(lateEntries.count) Verspätungen")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)

                // Entries
                if weekEntries.isEmpty {
                    VStack(spacing: 8) {
                        Text("🏃").font(.system(size: 48))
                        Text("Noch niemand zu spät!")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(weekEntries) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let person: Person

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: person.avatarColor).opacity(0.2))
                    .frame(width: 56, height: 56)
                Text(person.avatarEmoji)
                    .font(.system(size: 30))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Label("\(person.streak)", systemImage: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 22, weight: .bold))
                    if person.freezes > 0 {
                        Label("\(person.freezes)", systemImage: "snowflake")
                            .foregroundColor(.cyan)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
        .padding(.horizontal, 16)
    }
}

// MARK: - Entry Row

struct EntryRow: View {
    let entry: Entry

    var typeIcon: String {
        switch entry.type {
        case "attend": return "checkmark.circle.fill"
        case "skip":   return "xmark.circle.fill"
        default:       return "clock.fill"
        }
    }
    var typeColor: Color {
        switch entry.type {
        case "attend": return K.green
        case "skip":   return .secondary
        default:       return K.red
        }
    }
    var typeLabel: String {
        switch entry.type {
        case "attend": return "eingecheckt"
        case "skip":   return "skip"
        default:       return "\(entry.mins) Min."
        }
    }

    /// Entry logged offline, still waiting to reach the server.
    private var isPendingSync: Bool { entry.id.hasPrefix("local-") }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon)
                .foregroundColor(typeColor)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.person)
                    .font(.system(size: 15, weight: .semibold))
                Text(entry.date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isPendingSync {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Text(typeLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(typeColor)
        }
        .padding(14)
        .opacity(isPendingSync ? 0.6 : 1)
        .glassCard()
    }
}
