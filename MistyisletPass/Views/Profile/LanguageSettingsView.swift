import SwiftUI

struct LanguageSettingsView: View {
    @State private var settings = SettingsService.shared
    @State private var showRestartAlert = false

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        settings.selectedLanguage = language
                        showRestartAlert = true
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if settings.selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.brandPrimary)
                            }
                        }
                    }
                }
            } footer: {
                Text("Changing language requires restarting the app to take full effect.")
                    .font(.caption)
            }
        }
        .navigationTitle(String(localized: "profile.language"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Language Changed", isPresented: $showRestartAlert) {
            Button("OK") { }
        } message: {
            Text("Please restart the app to apply the language change.")
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
