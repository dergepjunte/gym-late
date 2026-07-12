import SwiftUI
import AuthenticationServices
import GoogleSignIn

/// Email/password (and, once configured, Apple/Google) account auth —
/// mirrors ProfileSetupSheet's NavigationStack+Form+mode-toggle pattern.
/// Serves three callers, distinguished by `purpose`:
///   .signup  — brand-new profile creation (ProfileSetupSheet gates on this)
///   .migrate — an existing recovery-code user upgrading (MigrationSheet)
///   .signin  — a returning account user on this device (LandingView)
struct AccountAuthSheet: View {
    enum Purpose { case signup, migrate, signin }
    enum Mode { case register, login }

    let purpose: Purpose
    var initialMode: Mode = .register
    var onCancel: (() -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .register
    @State private var email = ""
    @State private var password = ""
    @State private var error = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(K.L.de ? "E-Mail" : "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(K.L.de ? "Passwort" : "Password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                }
                ssoSection
                if !error.isEmpty {
                    Section { Text(error).foregroundColor(.red) }
                }
                Section {
                    Button(mode == .register
                           ? (K.L.de ? "Neues Konto erstellen →" : "Create a new account →")
                           : (K.L.de ? "Bereits ein Konto? Anmelden →" : "Already have an account? Sign in →")) {
                        withAnimation { mode = mode == .register ? .login : .register }
                        error = ""
                    }
                    .foregroundColor(K.accentDark)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GymBackground())
            .navigationTitle(mode == .register
                              ? (K.L.de ? "Konto erstellen" : "Create account")
                              : (K.L.de ? "Anmelden" : "Sign in"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if let onCancel { onCancel() } else { dismiss() }
                    } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .register ? (K.L.de ? "Erstellen" : "Create") : (K.L.de ? "Anmelden" : "Sign in")) {
                        Task { await submit() }
                    }
                    .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                }
            }
        }
        .onAppear { mode = initialMode }
    }

    // Apple requires the paid Apple Developer Program (for the Sign In with
    // Apple capability/entitlement) — not active yet, so the button is kept
    // out of the UI rather than shown non-functional. Flip this once the
    // entitlement is added to the target (see sso-credentials-progress memory).
    private let appleSignInEnabled = false

    @ViewBuilder
    private var ssoSection: some View {
        Section {
            if appleSignInEnabled {
                SignInWithAppleButton(.continue, onRequest: { req in
                    req.requestedScopes = [.email]
                }, onCompletion: { result in
                    Task { await handleApple(result) }
                })
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Button {
                Task { await handleGoogle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                    Text(K.L.de ? "Weiter mit Google" : "Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .disabled(isLoading)
        }
    }

    private func handleGoogle() async {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return }
        isLoading = true; error = ""
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                error = K.L.de ? "Google-Anmeldung fehlgeschlagen." : "Google sign-in failed."
                isLoading = false
                return
            }
            try await appState.googleSignIn(identityToken: idToken)
            await afterSuccess()
        } catch APIError.notConfigured {
            error = K.L.de ? "Anmeldung mit Google ist noch nicht verfügbar." : "Sign in with Google isn't available yet."
        } catch let gidError as GIDSignInError where gidError.code == .canceled {
            // User dismissed the Google sheet — not an error worth surfacing.
        } catch is GIDSignInError {
            // GIDSignInError's localizedDescription tends to be an internal,
            // Google-SDK-flavored string (e.g. keychain/EMM/scope errors) —
            // not something to show a user. One friendly fallback covers all
            // non-cancel cases; details aren't actionable for the user anyway.
            error = K.L.de ? "Google-Anmeldung fehlgeschlagen. Bitte erneut versuchen."
                           : "Google sign-in failed. Please try again."
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let auth) = result,
              let cred = auth.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else { return }
        isLoading = true; error = ""
        do {
            try await appState.appleSignIn(identityToken: token, email: cred.email)
            await afterSuccess()
        } catch APIError.notConfigured {
            error = K.L.de ? "Anmeldung mit Apple ist noch nicht verfügbar." : "Sign in with Apple isn't available yet."
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func submit() async {
        let e = email.trimmingCharacters(in: .whitespaces)
        isLoading = true; error = ""
        do {
            if mode == .register {
                try await appState.registerAccount(email: e, password: password)
            } else {
                try await appState.loginAccount(email: e, password: password)
            }
            await afterSuccess()
        } catch APIError.nameTaken {
            error = K.L.de ? "Diese E-Mail ist bereits registriert." : "This email is already registered."
        } catch APIError.unauthorized {
            error = K.L.de ? "Falsche E-Mail oder Passwort." : "Wrong email or password."
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func afterSuccess() async {
        if purpose == .migrate {
            await appState.migrateLinkAll()
        }
        dismiss()
    }
}

/// The requested "popup": offers an existing recovery-code user a one-tap
/// path to secure their account. Linking runs against EVERY locally-known
/// group at once (AppState.migrateLinkAll), not just the active one.
struct MigrationSheet: View {
    var onDone: () -> Void
    @State private var showAuth = false

    var body: some View {
        VStack(spacing: 20) {
            Text("🔐").font(.system(size: 56))
            Text(K.L.de ? "Konto sichern" : "Secure your account")
                .font(.title2.bold())
            Text(K.L.de
                 ? "Füge E-Mail & Passwort hinzu, damit du deine Gruppen nie verlierst — auch auf neuen Geräten."
                 : "Add email & password so you never lose access to your groups — even on new devices.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button { showAuth = true } label: {
                Text(K.L.de ? "E-Mail & Passwort einrichten" : "Set email & password")
                    .accentButton()
            }
            .padding(.horizontal)

            Button(K.L.de ? "Später" : "Later") { onDone() }
                .foregroundColor(K.accentDark)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding()
        .fullScreenCover(isPresented: $showAuth) {
            AccountAuthSheet(purpose: .migrate, onCancel: { showAuth = false })
        }
        .onChange(of: showAuth) { _, isShowing in
            // The auth sheet dismisses itself on success; once it's gone,
            // close this popup too so the user lands back in the app.
            if !isShowing { onDone() }
        }
    }
}

/// Persistent "secure your account" pill — independent of the one-shot
/// opening-sequence bubbles (Wrapped/Hype/Geo), so it's shown/dismissed on
/// its own schedule rather than competing with those ceremonies.
struct MigrateBannerView: View {
    let onTap: () -> Void
    let onDismiss: () -> Void
    @State private var appeared = false
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 14) {
            Text("🔐")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(LinearGradient(
                        colors: [Color(hex: "#6366f1"), Color(hex: "#4338ca")],
                        startPoint: .topLeading, endPoint: .bottomTrailing)))

            VStack(alignment: .leading, spacing: 2) {
                Text(K.L.de ? "Konto sichern" : "Secure your account")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(K.L.de ? "Tippe, um dein Konto zu sichern" : "Tap to secure your account")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color(.systemFill)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color(hex: "#818cf8").opacity(0.45), lineWidth: 1))
        // Deliberately more attention-grabbing than the ceremony bubbles: a
        // slow pulsing glow, since this banner reappears every app open
        // (not a one-time nag) until the user actually migrates.
        .shadow(color: Color(hex: "#6366f1").opacity(pulsing ? 0.55 : 0.25), radius: pulsing ? 30 : 18, x: 0, y: 4)
        .onTapGesture { onTap() }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.42, dampingFraction: 0.76), value: appeared)
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}
