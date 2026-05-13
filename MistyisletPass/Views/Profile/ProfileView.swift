import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = ProfileViewModel()
    @State private var settings = SettingsService.shared
    @State private var selectedTab: SettingsTab = .main

    private enum SettingsTab: CaseIterable {
        case main, logins, help

        @MainActor func label(_ s: SettingsService) -> String {
            switch self {
            case .main: return s.L("profile.tab_main")
            case .logins: return s.L("profile.tab_logins")
            case .help: return s.L("profile.tab_help")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Settings", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Text(tab.label(settings)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedTab {
                case .main:
                    MainSettingsTab(
                        viewModel: viewModel,
                        settings: settings,
                        authViewModel: authViewModel
                    )
                case .logins:
                    LoginsTab(viewModel: viewModel)
                case .help:
                    HelpTab()
                }
            }
            .navigationTitle(settings.L("profile.title"))
            .task {
                await viewModel.fetchProfile()
            }
        }
        .environment(viewModel)
    }
}

// MARK: - Main Settings Tab

private struct MainSettingsTab: View {
    let viewModel: ProfileViewModel
    @Bindable var settings: SettingsService
    let authViewModel: AuthViewModel
    @State private var avatarItem: PhotosPickerItem?

    var body: some View {
        List {
            profileHeader
            settingsItems
            signOutSection
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.fetchProfile() }
        .onChange(of: avatarItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await viewModel.uploadAvatar(data)
                }
            }
        }
    }

    private var profileHeader: some View {
        Section {
            if let user = viewModel.user {
                HStack(spacing: 16) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if let avatarURL = user.avatar, let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .foregroundStyle(.brandPrimary)
                                    }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.brandPrimary)
                            }

                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, .brandPrimary)
                                .offset(x: 2, y: 2)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(user.email)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("\(user.organizationName ?? "") \u{00B7} \(user.roleDisplayLabel ?? user.role)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
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

    private var settingsItems: some View {
        Section(settings.L("profile.settings")) {
            NavigationLink {
                ChangePasswordView(viewModel: viewModel)
            } label: {
                Label(settings.L("profile.change_password"), systemImage: "key")
            }

            Toggle(isOn: $settings.biometricEnabled) {
                Label(biometricLabel, systemImage: biometricIcon)
            }
            .tint(.brandPrimary)

            NavigationLink {
                LanguageSettingsView()
            } label: {
                HStack {
                    Label(settings.L("profile.language"), systemImage: "globe")
                    Spacer()
                    Text(settings.selectedLanguage.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                GeofenceSettingsView()
            } label: {
                Label(settings.L("profile.auto_unlock_zone"), systemImage: "location.circle")
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
                    Label(settings.L("profile.sign_out"), systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                }
            }
        }
    }

    private var biometricLabel: String {
        switch BiometricService.shared.deviceBiometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return settings.L("profile.biometric_lock")
        }
    }

    private var biometricIcon: String {
        switch BiometricService.shared.deviceBiometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock"
        }
    }
}

// MARK: - Logins Tab

private struct LoginsTab: View {
    let viewModel: ProfileViewModel
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            if viewModel.isLoadingLogins {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.logins.isEmpty {
                ContentUnavailableView(
                    settings.L("profile.no_sessions"),
                    systemImage: "iphone.and.arrow.forward",
                    description: Text(settings.L("profile.no_sessions_description"))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.logins) { login in
                    LoginSessionRow(login: login) {
                        Task { await viewModel.remoteLogout(login) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task {
            await viewModel.fetchLogins()
        }
    }
}

// MARK: - Help Tab

private struct HelpTab: View {
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            NavigationLink {
                AboutView()
            } label: {
                Label(settings.L("profile.about"), systemImage: "info.circle")
            }

            NavigationLink {
                Text(settings.L("profile.help_center"))
                    .navigationTitle(settings.L("profile.help_center"))
            } label: {
                Label(settings.L("profile.help_center"), systemImage: "questionmark.circle")
            }

            NavigationLink {
                Text(settings.L("profile.acknowledgments"))
                    .navigationTitle(settings.L("profile.acknowledgments"))
            } label: {
                Label(settings.L("profile.acknowledgments"), systemImage: "doc.text")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - About

struct AboutView: View {
    @State private var settings = SettingsService.shared
    @State private var tapCount = 0
    @State private var showDevOptions = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text(settings.L("profile.version"))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    tapCount += 1
                    if tapCount >= 7 {
                        showDevOptions = true
                        tapCount = 0
                    }
                }

                HStack {
                    Text(settings.L("profile.build"))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }

                LabeledContent(settings.L("profile.device_label"), value: "\(deviceModel)")
                LabeledContent("iOS", value: UIDevice.current.systemVersion)

                HStack {
                    Text(settings.L("profile.environment"))
                    Spacer()
                    Text(Constants.AppEnvironment.current.rawValue.capitalized)
                        .foregroundStyle(environmentColor)
                        .fontWeight(.medium)
                }
            }

            #if DEBUG
            if showDevOptions {
                Section("Developer Options") {
                    ForEach(devEnvironments, id: \.self) { env in
                        HStack {
                            Text(env.rawValue.capitalized)
                            Spacer()
                            if env == Constants.AppEnvironment.current {
                                Text("(\(settings.L("profile.active")))")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }

                    NavigationLink {
                        TCPAuthTestView()
                    } label: {
                        Label("TCP Auth Test", systemImage: "network")
                    }
                }
            }
            #endif

            Section {
                Text(settings.L("profile.app_description"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(settings.L("profile.about"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "Unknown"
            }
        }
        return model
    }

    private var environmentColor: Color {
        switch Constants.AppEnvironment.current {
        case .dev: return .orange
        case .staging: return .yellow
        case .production: return .green
        case .mock: return .purple
        }
    }

    #if DEBUG
    private var devEnvironments: [Constants.AppEnvironment] {
        [.dev, .staging, .production, .mock]
    }
    #endif
}

// MARK: - Change Password

struct ChangePasswordView: View {
    let viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsService.shared

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var isValid: Bool {
        !currentPassword.isEmpty && passwordsMatch
    }

    var body: some View {
        Form {
            Section {
                SecureField(settings.L("profile.current_password"), text: $currentPassword)
                    .textContentType(.password)
            }

            Section {
                SecureField(settings.L("profile.new_password"), text: $newPassword)
                    .textContentType(.newPassword)
                SecureField(settings.L("profile.confirm_password"), text: $confirmPassword)
                    .textContentType(.newPassword)

                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text(settings.L("profile.passwords_mismatch"))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                Button(settings.L("profile.update_password")) {
                    Task {
                        let success = await viewModel.changePassword(
                            currentPassword: currentPassword,
                            newPassword: newPassword
                        )
                        if success { dismiss() }
                    }
                }
                .frame(maxWidth: .infinity)
                .disabled(!isValid)
            }
        }
        .navigationTitle(settings.L("profile.change_password"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environment(AuthViewModel())
}
