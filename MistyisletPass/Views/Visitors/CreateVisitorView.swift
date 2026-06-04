import SwiftUI

struct CreateVisitorView: View {
    @Environment(VisitorsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsService.shared

    @State private var name = ""
    @State private var selectedTTL = 24
    @State private var deliveryMethod: DeliveryMethod = .emailQR

    private let ttlOptions = [4, 8, 24, 48, 72]

    // Only the values the backend accepts (`normalizeDeliveryMethod` in
    // api/internal/modules/access/service_policies.go: wallet, email_qr).
    // Other channels (whatsapp/sms/email) are not delivered server-side and
    // were rejected on create, so they are not offered here.
    enum DeliveryMethod: String, CaseIterable, Identifiable {
        case emailQR = "email_qr"
        case wallet = "wallet"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .emailQR: return "Email + QR"
            case .wallet: return "Wallet"
            }
        }

        var icon: String {
            switch self {
            case .emailQR: return "qrcode"
            case .wallet: return "wallet.pass"
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.L("visitors.visitor_info")) {
                    TextField(settings.L("visitors.name"), text: $name)
                        .textContentType(.name)
                }

                Section(settings.L("visitors.delivery_method")) {
                    Picker(settings.L("visitors.send_via"), selection: $deliveryMethod) {
                        ForEach(DeliveryMethod.allCases) { method in
                            Label(method.label, systemImage: method.icon)
                                .tag(method)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(settings.L("visitors.duration")) {
                    Picker(settings.L("visitors.duration"), selection: $selectedTTL) {
                        ForEach(ttlOptions, id: \.self) { hours in
                            Text(String(format: settings.L("visitors.hours"), hours)).tag(hours)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(settings.L("visitors.notes")) {
                    Text(settings.L("visitors.notes_description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(settings.L("visitors.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.L("visitors.create")) {
                        Task {
                            await viewModel.createVisitor(
                                name: name,
                                ttlHours: Double(selectedTTL),
                                deliveryMethod: deliveryMethod.rawValue
                            )
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!isValid || viewModel.isLoading)
                }
            }
        }
    }
}

#Preview {
    CreateVisitorView()
        .environment(VisitorsViewModel())
}
