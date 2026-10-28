import SwiftUI

// MARK: - Model

/// Laedt den Gruppen-Chat, haelt ihn aktuell (Polling im Vordergrund) und fuehrt Aktionen aus.
@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var members = 0
    @Published var error: String?
    @Published var sending = false
    private var lastSystemId: String?

    private var context: (groupId: String, auth: ChatAuth)? {
        let app = AppState.shared
        guard let g = app.activeGroup, let p = app.userProfile else { return nil }
        return (g.id, ChatAuth(userId: p.userId, recoveryCode: p.recoveryCode,
                               accountToken: app.account?.accountToken))
    }

    /// Vorschau: Chat aus Sicht eines anderen Mitglieds (nur ansehen, nichts senden/abstimmen).
    @Published var viewAs: String?
    var myId: String? { viewAs ?? AppState.shared.userProfile?.userId }

    func refresh() async {
        guard let c = context else { return }
        do { apply(try await APIClient.shared.chatList(groupId: c.groupId, auth: c.auth)) }
        catch { /* offline: alten Stand behalten */ }
    }

    func send(_ text: String) async {
        guard let c = context else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        sending = true
        do { apply(try await APIClient.shared.chatSend(groupId: c.groupId, auth: c.auth, text: t)) }
        catch { self.error = K.L.errServer }
        sending = false
    }

    func propose(date: String, time: String) async -> Bool {
        guard let c = context else { return false }
        sending = true
        defer { sending = false }
        do {
            apply(try await APIClient.shared.chatPropose(groupId: c.groupId, auth: c.auth, date: date, time: time))
            return true
        } catch {
            self.error = K.L.errServer
            return false
        }
    }

    func vote(_ message: ChatMessage, yes: Bool) async {
        guard viewAs == nil, let c = context else { return }
        do { apply(try await APIClient.shared.chatVote(groupId: c.groupId, auth: c.auth, messageId: message.id, yes: yes)) }
        catch { await refresh() }   // z. B. schon entschieden
    }

    private func apply(_ snap: ChatSnapshot) {
        members = snap.members
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { messages = snap.messages }
        // Neue feste Zeit → Wochenansicht (Chip "Check-in um …") sofort aktualisieren.
        if let sys = snap.messages.last(where: { $0.kind == "system" }), sys.id != lastSystemId {
            if lastSystemId != nil { Task { await AppState.shared.refreshData() } }
            lastSystemId = sys.id
        }
    }
}

// MARK: - View

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var model = ChatModel()
    @State private var draft = ""
    @State private var showPropose = false
    @State private var toast: String?
    @FocusState private var focused: Bool

    private func person(_ id: String) -> Person? { appState.groupData?.people.first { $0.id == id } }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(toast: $toast)
                .padding(.bottom, 4)

            viewAsBar

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if model.messages.isEmpty {
                            emptyState.padding(.top, 60)
                        }
                        ForEach(model.messages) { m in
                            row(m).id(m.id)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                        removal: .opacity))
                        }
                        Color.clear.frame(height: 4).id("bottom")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            }

            if model.viewAs == nil { composer } else { previewNote }
        }
        .task {
            await model.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await model.refresh()
            }
        }
        .sheet(isPresented: $showPropose) {
            ProposeTimeSheet(model: model).presentationDetents([.height(380)])
        }
        .alert(K.L.de ? "Chat" : "Chat", isPresented: Binding(get: { model.error != nil },
                                                               set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .toast($toast)
    }

    // MARK: Ansicht als anderes Mitglied

    private var others: [Person] {
        (appState.groupData?.people ?? []).filter { $0.id != appState.userProfile?.userId }
    }

    @ViewBuilder
    private var viewAsBar: some View {
        if !others.isEmpty {
            HStack {
                Menu {
                    Button { withAnimation { model.viewAs = nil } } label: {
                        Label(K.L.de ? "Meine Ansicht" : "My view", systemImage: model.viewAs == nil ? "checkmark" : "person")
                    }
                    ForEach(others, id: \.id) { p in
                        Button { withAnimation { model.viewAs = p.id } } label: {
                            Label(p.name, systemImage: model.viewAs == p.id ? "checkmark" : "eye")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye").font(.system(size: 13, weight: .semibold))
                        Text(model.viewAs.flatMap { person($0)?.name }.map { (K.L.de ? "Ansicht: " : "View: ") + $0 }
                             ?? (K.L.de ? "Ansicht der anderen" : "See others' view"))
                            .font(Theme.body(13, .semibold))
                    }
                    .foregroundColor(K.amberText)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.bottom, 4)
        }
    }

    private var previewNote: some View {
        Text(K.L.de ? "Nur Vorschau – so sieht \(person(model.viewAs ?? "")?.name ?? "die Person") den Chat."
                    : "Preview only – this is how \(person(model.viewAs ?? "")?.name ?? "they") see the chat.")
            .font(Theme.body(13, .semibold)).foregroundColor(.secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 18)
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ m: ChatMessage) -> some View {
        switch m.kind {
        case "time_proposal": ProposalCard(message: m, model: model, proposer: person(m.userId))
        case "system": systemRow(m)
        default: bubble(m)
        }
    }

    private func bubble(_ m: ChatMessage) -> some View {
        let mine = m.userId == model.myId
        let p = person(m.userId)
        return HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 44) }
            else if let p { AvatarView(emoji: p.avatarEmoji, color: p.avatarColor, img: p.avatarImg, size: 30) }
            else { Color.clear.frame(width: 30, height: 30) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if !mine, let p { Text(p.name).font(Theme.body(11, .semibold)).foregroundColor(.secondary) }
                Text(m.text ?? "")
                    .font(Theme.body(16))
                    .foregroundColor(mine ? K.onAccent : .primary)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(
                        Group {
                            if mine {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(LinearGradient(colors: Theme.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            } else {
                                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                            }
                        })
            }
            if !mine { Spacer(minLength: 44) }
        }
    }

    private func systemRow(_ m: ChatMessage) -> some View {
        let time = m.propTime ?? ""
        return HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill").foregroundColor(K.green)
            Text(K.L.de ? "\(ChatFormat.dayWord(m.propDate)) steht die Gym-Zeit fest: \(time)"
                        : "\(ChatFormat.dayWord(m.propDate)) gym time is set: \(time)")
                .font(Theme.body(13, .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(K.green.opacity(0.14)))
        .overlay(Capsule().strokeBorder(K.green.opacity(0.35), lineWidth: 1))
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("💬").font(.system(size: 44))
            Text(K.L.de ? "Noch nichts los hier" : "Nothing here yet")
                .font(Theme.heading(18))
            Text(K.L.de ? "Schreib was oder schlag eine Gym-Zeit für heute vor – sie gilt, wenn die Gruppe zustimmt."
                        : "Say something or propose today's gym time – it counts once the group agrees.")
                .font(Theme.body(14)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
    }

    // MARK: Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button { focused = false; showPropose = true; haptic(.light) } label: {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(K.amberText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }
            .accessibilityLabel(K.L.de ? "Gym-Zeit vorschlagen" : "Propose gym time")

            TextField(K.L.de ? "Nachricht …" : "Message …", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))

            Button {
                let t = draft; draft = ""; haptic(.light)
                Task { await model.send(t) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(K.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(LinearGradient(colors: Theme.accentGradient,
                                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

// MARK: - Proposal card

struct ProposalCard: View {
    let message: ChatMessage
    @ObservedObject var model: ChatModel
    let proposer: Person?

    private var myVote: Bool? {
        guard let me = model.myId else { return nil }
        if message.yes.contains(me) { return true }
        if message.no.contains(me) { return false }
        return nil
    }
    private var open: Bool { message.status == "open" }

    var body: some View {
        let yes = message.yes.count
        let total = max(model.members, 1)
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if let p = proposer { AvatarView(emoji: p.avatarEmoji, color: p.avatarColor, img: p.avatarImg, size: 30) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(K.L.de ? "\(proposer?.name ?? "Jemand") schlägt vor" : "\(proposer?.name ?? "Someone") proposes")
                        .font(Theme.body(12, .semibold)).foregroundColor(.secondary)
                    Text(ChatFormat.dayWord(message.propDate, capital: true))
                        .font(Theme.body(12)).foregroundColor(.secondary)
                }
                Spacer()
                statusChip
            }

            Text(message.propTime ?? "--:--")
                .font(.system(size: 46, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(LinearGradient(colors: Theme.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))

            // Fortschritt: Zustimmungen gegen Mehrheit
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule().fill(message.status == "rejected" ? K.red : K.green)
                            .frame(width: geo.size.width * CGFloat(yes) / CGFloat(total))
                            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: yes)
                    }
                }
                .frame(height: 8)
                Text(K.L.de ? "\(yes) von \(total) dafür" : "\(yes) of \(total) in")
                    .font(Theme.body(12)).foregroundColor(.secondary)
            }

            if open {
                HStack(spacing: 10) {
                    voteButton(yes: true)
                    voteButton(yes: false)
                }
            }
        }
        .padding(16)
        .glassCard(radius: 24)
    }

    private var statusChip: some View {
        let (text, color): (String, Color) = {
            switch message.status {
            case "accepted":   return (K.L.de ? "Fest ✓" : "Set ✓", K.green)
            case "rejected":   return (K.L.de ? "Abgelehnt" : "Rejected", K.red)
            case "superseded": return (K.L.de ? "Überholt" : "Replaced", .secondary)
            default:           return (K.L.de ? "Offen" : "Open", K.accentDeep)
            }
        }()
        return Text(text).font(Theme.body(11, .bold)).foregroundColor(color)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func voteButton(yes: Bool) -> some View {
        let selected = myVote == yes
        let textColor: Color = selected ? (yes ? K.onAccent : Color.white) : Color.primary
        let fillColor: Color = selected ? (yes ? K.green : K.red) : Color.primary.opacity(0.08)
        return Button {
            haptic(.light)
            Task { await model.vote(message, yes: yes) }
        } label: {
            Text(yes ? (K.L.de ? "Passt ✓" : "I'm in ✓") : (K.L.de ? "Nein" : "No"))
                .font(Theme.heading(15))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Capsule().fill(fillColor))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }
}

// MARK: - Propose sheet

struct ProposeTimeSheet: View {
    @ObservedObject var model: ChatModel
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date = {
        var c = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        c.hour = max((c.hour ?? 17) + 1, 6); c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var tomorrow = false

    var body: some View {
        VStack(spacing: 14) {
            Text(K.L.de ? "Gym-Zeit vorschlagen" : "Propose gym time").font(Theme.heading(20)).padding(.top, 20)
            Picker("", selection: $tomorrow) {
                Text(K.L.de ? "Heute" : "Today").tag(false)
                Text(K.L.de ? "Morgen" : "Tomorrow").tag(true)
            }
            .pickerStyle(.segmented).padding(.horizontal, 24)

            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel).labelsHidden()

            Text(K.L.de ? "Fest wird die Zeit, sobald die Mehrheit der Gruppe zustimmt."
                        : "The time becomes fixed once most of the group agrees.")
                .font(Theme.body(12)).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)

            Button {
                let f = DateFormatter(); f.dateFormat = "HH:mm"
                let day = Calendar.current.date(byAdding: .day, value: tomorrow ? 1 : 0, to: Date()) ?? Date()
                Task {
                    if await model.propose(date: dateYMD(day), time: f.string(from: time)) {
                        hapticSuccess(); dismiss()
                    }
                }
            } label: {
                Text(K.L.de ? "Vorschlagen" : "Propose").accentButton()
            }
            .disabled(model.sending)
            .padding(.horizontal, 24).padding(.bottom, 10)
        }
    }
}

// MARK: - Helpers

enum ChatFormat {
    /// "Heute", "Morgen" oder das Datum.
    static func dayWord(_ ymd: String?, capital: Bool = false) -> String {
        guard let ymd else { return "" }
        let today = dateYMD(Date())
        let tomorrow = dateYMD(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let de = K.L.de
        if ymd == today { return capital ? (de ? "Heute" : "Today") : (de ? "Heute" : "Today") }
        if ymd == tomorrow { return de ? "Morgen" : "Tomorrow" }
        return ymd
    }
}
