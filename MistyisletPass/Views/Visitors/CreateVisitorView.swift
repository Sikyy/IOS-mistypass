import SwiftUI

struct CreateVisitorView: View {
    @Environment(VisitorsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsService.shared

    @State private var name = ""
    @State private var selectedTTL = 24
    @State private var deliveryMethod: DeliveryMethod = .whatsapp

    private let ttlOptions = [4, 8, 24, 48, 72]

    enum DeliveryMethod: String, CaseIterable, Identifiable {
        case email = "email"
        case emailQR = "email_qr"
        case whatsapp = "whatsapp"
        case whatsappQR = "whatsapp_qr"
        case sms = "sms"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .email: return "Email"
            case .emailQR: return "Email + QR"
            case .whatsapp: return "WhatsApp"
            case .whatsappQR: return "WhatsApp + QR"
            case .sms: return "SMS"
            }
        }

        var icon: String {
            switch self {
            case .email: return "envelope"
            case .emailQR: return "qrcode"
            case .whatsapp: return "bubble.left.fill"
            case .whatsappQR: return "qrcode"
            case .sms: return "message"
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
