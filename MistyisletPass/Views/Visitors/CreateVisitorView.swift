import SwiftUI

struct CreateVisitorView: View {
    let viewModel: VisitorsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var hostName = ""
    @State private var company = ""
    @State private var purpose = ""
    @State private var selectedTTL = 24
    @State private var selectedDoorIds: Set<String> = []

    private let ttlOptions = [4, 8, 24, 48, 72]

    private var isValid: Bool {
        !name.isEmpty && !phone.isEmpty && !hostName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Visitor Information") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Company (optional)", text: $company)
                        .textContentType(.organizationName)
                    TextField("Purpose (optional)", text: $purpose)
                }

                Section("Host") {
                    TextField("Host Name", text: $hostName)
                        .textContentType(.name)
                }

                Section("Access Duration") {
                    Picker("Duration", selection: $selectedTTL) {
                        ForEach(ttlOptions, id: \.self) { hours in
                            Text("\(hours) hours").tag(hours)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    Text("The visitor will receive a QR code for door access that expires after the selected duration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Visitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createVisitor(
                                name: name,
                                phone: phone,
                                hostName: hostName,
                                company: company.isEmpty ? nil : company,
                                purpose: purpose.isEmpty ? nil : purpose,
                                doorIds: Array(selectedDoorIds),
                                ttlHours: selectedTTL
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
    CreateVisitorView(viewModel: VisitorsViewModel())
}
