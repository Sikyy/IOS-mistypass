import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        @Bindable var vm = authViewModel

        NavigationStack {
            Group {
                switch vm.authStep {
                case .emailEntry:
                    EmailEntryStep()
                case .domainEntry:
                    DomainEntryStep()
                case .credentials:
                    CredentialsStep()
                case .magicLinkSent:
                    MagicLinkSentStep()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.authStep)
        }
    }
}

// MARK: - Step 1: Email Entry (Magic Link)

private struct EmailEntryStep: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @FocusState private var isFocused: Bool
    @State private var settings = SettingsService.shared

    var body: some View {
        @Bindable var vm = authViewModel

        VStack(alignment: .leading, spacing: 0) {
            appLogo
                .padding(.top, 16)
                .padding(.bottom, 32)

            Text(settings.L("auth.enter_email"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 12)

            Text(settings.L("auth.enter_email_description"))
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)

            TextField(settings.L("auth.email"), text: $vm.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.brandPrimary : Color(.systemGray4), lineWidth: isFocused ? 2 : 1)
                )

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer()

            HStack {
                Button(settings.L("auth.manual_sign_in")) {
                    authViewModel.goToManualSignIn()
                }
                .foregroundStyle(.brandPrimary)

                Spacer()

                Button {
                    Task { await authViewModel.requestMagicLink() }
                } label: {
                    Text(settings.L("auth.continue"))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.email.isEmpty ? Color(.systemGray5) : .brandPrimary)
                .foregroundStyle(vm.email.isEmpty ? Color.secondary : Color.white)
                .disabled(vm.email.isEmpty || authViewModel.isLoading)
            }

            #if DEBUG
            if Constants.AppEnvironment.current == .dev {
                Button("Dev Login (siky)") {
                    vm.email = "siky@mistyislet.com"
                    vm.orgDomain = "test"
                    Task { await authViewModel.login(email: "siky@mistyislet.com", password: "65552588") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .task { await authViewModel.devAutoLogin() }
            }
            #endif
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Step 2: Organization Domain

private struct DomainEntryStep: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @FocusState private var isFocused: Bool
    @State private var settings = SettingsService.shared

    var body: some View {
        @Bindable var vm = authViewModel

        VStack(alignment: .leading, spacing: 0) {
            Button {
                authViewModel.goBack()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)

            Text(settings.L("auth.sign_in_org"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 12)

            Text(settings.L("auth.enter_domain"))
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)

            TextField(settings.L("auth.org_domain"), text: $vm.orgDomain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.brandPrimary : Color(.systemGray4), lineWidth: isFocused ? 2 : 1)
                )

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer()

            HStack {
                Button(settings.L("auth.no_domain")) {
                    authViewModel.skipDomain()
                }
                .foregroundStyle(.brandPrimary)

                Spacer()

                Button {
                    Task { await authViewModel.lookupOrganization() }
                } label: {
                    Text(settings.L("auth.continue"))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.orgDomain.isEmpty ? Color(.systemGray5) : .brandPrimary)
                .foregroundStyle(vm.orgDomain.isEmpty ? Color.secondary : Color.white)
                .disabled(vm.orgDomain.isEmpty || authViewModel.isLoading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Step 3: Credentials

private struct CredentialsStep: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var settings = SettingsService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showForgotPassword = false
    @State private var forgotEmail = ""
    @State private var forgotSuccess = false
    @FocusState private var focusedField: CredentialField?

    private enum CredentialField {
        case email, password
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                authViewModel.goBack()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)

            Text(settings.L("auth.sign_in_org"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 12)

            Text(settings.L("auth.enter_credentials"))
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)

            if let org = authViewModel.orgConfig {
                orgHeader(org)
                    .padding(.bottom, 24)
            }

            VStack(spacing: 20) {
                TextField(settings.L("auth.email"), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == .email ? Color.brandPrimary : Color(.systemGray4), lineWidth: focusedField == .email ? 2 : 1)
                    )

                HStack {
                    Group {
                        if showPassword {
                            TextField(settings.L("auth.password"), text: $password)
                        } else {
                            SecureField(settings.L("auth.password"), text: $password)
                        }
                    }
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye" : "eye.slash")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .password ? Color.brandPrimary : Color(.systemGray4), lineWidth: focusedField == .password ? 2 : 1)
                )
            }

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }

            Spacer()

            HStack {
                Button(settings.L("auth.forgot_password")) {
                    forgotEmail = email
                    showForgotPassword = true
                }
                .foregroundStyle(.primary)

                Spacer()

                Button {
                    Task { await authViewModel.login(email: email, password: password) }
                } label: {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(settings.L("auth.sign_in"))
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(isValid ? .brandPrimary : Color(.systemGray5))
                .foregroundStyle(isValid ? Color.white : Color.secondary)
                .disabled(!isValid || authViewModel.isLoading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear {
            if !authViewModel.email.isEmpty { email = authViewModel.email }
        }
        .onSubmit {
            switch focusedField {
            case .email: focusedField = .password
            case .password:
                if isValid { Task { await authViewModel.login(email: email, password: password) } }
            case nil: break
            }
        }
        .alert(settings.L("auth.reset_password"), isPresented: $showForgotPassword) {
            TextField(settings.L("auth.email"), text: $forgotEmail)
                .textContentType(.emailAddress)
            Button(settings.L("common.cancel"), role: .cancel) {}
            Button(settings.L("auth.send_reset_link")) {
                Task {
                    await authViewModel.restorePassword(email: forgotEmail)
                    forgotSuccess = true
                }
            }
        } message: {
            Text(settings.L("auth.reset_description"))
        }
        .alert(settings.L("auth.email_sent"), isPresented: $forgotSuccess) {
            Button(settings.L("common.ok")) {}
        } message: {
            Text(settings.L("auth.reset_confirmation"))
        }
    }

    private var isValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func orgHeader(_ org: OrgAuthConfig) -> some View {
        HStack(spacing: 12) {
            if let logo = org.logo, let url = URL(string: logo) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    orgInitial(org.name)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                orgInitial(org.name)
            }

            Text(org.name)
                .font(.body)
                .fontWeight(.medium)
        }
    }

    private func orgInitial(_ name: String) -> some View {
        Text(name.prefix(1).uppercased())
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Color.brandPrimary)
            .clipShape(Circle())
    }
}

// MARK: - Magic Link Sent

private struct MagicLinkSentStep: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var settings = SettingsService.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(.brandPrimary)

            Text(settings.L("auth.check_email"))
                .font(.title2)
                .fontWeight(.bold)

            Text(String(format: settings.L("auth.magic_link_sent"), authViewModel.email))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Button(settings.L("auth.resend_link")) {
                    Task { await authViewModel.requestMagicLink() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPrimary)
                .disabled(authViewModel.isLoading)

                Button(settings.L("auth.back_to_sign_in")) {
                    authViewModel.goBack()
                }
                .foregroundStyle(.brandPrimary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - App Logo

private var appLogo: some View {
    HStack(spacing: 6) {
        Circle()
            .fill(Color.primary)
            .frame(width: 20, height: 20)
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.primary)
            .frame(width: 32, height: 20)
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
