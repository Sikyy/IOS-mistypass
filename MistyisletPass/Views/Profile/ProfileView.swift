import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = ProfileViewModel()
    @State private var settings = SettingsService.shared

    var body: some View {
        NavigationStack {
            List {
                userSection
                siteSection
                credentialsSection
                settingsSection
                signOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "profile.title"))
            .task {
                await viewModel.fetchProfile()
            }
        }
    }

    // MARK: - User Info

    private var userSection: some View {
        Section {
            if let user = viewModel.user {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.brandPrimary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("\(user.building) \u{00B7} \(user.role)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }

    // MARK: - Site Switching

    private var siteSection: some View {
        Section {
            NavigationLink {
                SiteSwitcherView(viewModel: viewModel)
            } label: {
                HStack {
                    Label("Site", systemImage: "building.2")
                    Spacer()
                    Text(settings.selectedSiteName ?? "All Sites")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        Section(String(localized: "profile.credentials")) {
            ForEach(viewModel.credentials) { credential in
                CredentialRowView(
                    credential: credential,
                    onRevoke: {
                        Task { await viewModel.revokeCredential(credential) }
                    }
                )
            }

            // NFC Card Binding
            if NFCService.shared.isAvailable {
                NavigationLink {
                    NFCBindingView(viewModel: viewModel)
                } label: {
                    Label("Bind NFC Card", systemImage: "wave.3.right")
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        Section(String(localized: "profile.settings")) {
            // Language
            NavigationLink {
                LanguageSettingsView()
            } label: {
                HStack {
                    Label(String(localized: "profile.language"), systemImage: "globe")
                    Spacer()
                    Text(settings.selectedLanguage.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            // Biometric
            Toggle(isOn: Bindable(settings).biometricEnabled) {
                Label(
                    String(localized: "profile.biometric_lock"),
                    systemImage: biometricIcon
                )
            }
            .tint(.brandPrimary)

            // Haptic
            Toggle(isOn: Bindable(settings).hapticEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap")
            }
            .tint(.brandPrimary)

            // Screen brightness
            Toggle(isOn: Bindable(settings).autoScreenBrightness) {
                Label("Auto Brightness for Pass", systemImage: "sun.max")
            }
            .tint(.brandPrimary)

            // Geofence
            NavigationLink {
                GeofenceSettingsView()
            } label: {
                Label("Auto-Unlock Zone", systemImage: "location.circle")
            }

            // Notifications
            NavigationLink {
                Text("Notification Settings")
            } label: {
                Label(String(localized: "profile.notifications"), systemImage: "bell")
            }

            // About
            NavigationLink {
                AboutView()
            } label: {
                Label(String(localized: "profile.about"), systemImage: "info.circle")
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                authViewModel.logout()
            } label: {
                HStack {
                    Spacer()
                    Text(String(localized: "profile.sign_out"))
                    Spacer()
                }
            }
        }
    }

    private var biometricIcon: String {
        switch BiometricService.shared.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock"
        }
    }
}

// MARK: - Credential Row

struct CredentialRowView: View {
    let credential: Credential
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundStyle(.brandPrimary)
                Text(credential.deviceName)
                    .font(.headline)
            }

            HStack {
                Text(String(localized: "profile.secure_enclave"))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())

                Text(credential.isActive
                     ? String(localized: "profile.active")
                     : String(localized: "profile.revoked"))
                    .font(.caption)
                    .foregroundStyle(credential.isActive ? .green : .red)
            }

            HStack {
                Text("Expires: \(credential.expiresAt, style: .date)")
                    .font(.caption)
                    .foregroundStyle(credential.isExpiringSoon ? .orange : .secondary)

                Spacer()

                if credential.isActive {
                    Button(String(localized: "profile.revoke"), role: .destructive) {
                        onRevoke()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Mistyislet is a mobile access control application for the Indonesian SaaS access control platform.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "profile.about"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environment(AuthViewModel())
}
