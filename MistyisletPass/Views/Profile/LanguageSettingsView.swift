import SwiftUI

struct LanguageSettingsView: View {
    @State private var settings = SettingsService.shared

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        withAnimation {
                            settings.selectedLanguage = language
                        }
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
            }
        }
        .navigationTitle(settings.L("profile.language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
