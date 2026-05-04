import SwiftUI
import UIKit

struct VisitorsView: View {
    @State private var viewModel = VisitorsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.visitors.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Visitors",
                        systemImage: "person.badge.plus",
                        description: Text("Create visitor passes to grant temporary access.")
                    )
                } else {
                    visitorList
                }
            }
            .navigationTitle("Visitors")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.fetchVisitors()
            }
            .task {
                await viewModel.fetchVisitors()
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateVisitorView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.createdVisitor) { visitor in
                VisitorQRView(visitor: visitor, viewModel: viewModel)
            }
        }
    }

    private var visitorList: some View {
        List {
            if !viewModel.activeVisitors.isEmpty {
                Section("Active Passes") {
                    ForEach(viewModel.activeVisitors) { visitor in
                        VisitorRowView(visitor: visitor, viewModel: viewModel)
                    }
                }
            }

            if !viewModel.expiredVisitors.isEmpty {
                Section("Expired") {
                    ForEach(viewModel.expiredVisitors) { visitor in
                        VisitorRowView(visitor: visitor, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct VisitorRowView: View {
    let visitor: Visitor
    let viewModel: VisitorsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(visitor.name)
                    .font(.headline)
                Spacer()
                if visitor.isExpired {
                    Text("Expired")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let company = visitor.company {
                Text("\(company) \u{00B7} \(visitor.purpose ?? "Visit")")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if !visitor.isExpired {
                HStack {
                    Text(visitor.timeRemaining)
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Spacer()

                    Button {
                        viewModel.createdVisitor = visitor
                    } label: {
                        Image(systemName: "qrcode")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - QR Display

struct VisitorQRView: View {
    let visitor: Visitor
    let viewModel: VisitorsViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(visitor.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                if let qrData = viewModel.generateQRCode(from: visitor.accessToken),
                   let uiImage = UIImage(data: qrData) {
                    Image(uiImage: uiImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .accessibilityLabel("QR access code for visitor \(visitor.name), \(visitor.timeRemaining)")
                }

                Text(visitor.timeRemaining)
                    .font(.callout)
                    .foregroundStyle(.orange)

                Text("Doors: \(visitor.doorNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    ShareLink(
                        item: visitor.accessToken,
                        subject: Text("Visitor Access Pass"),
                        message: Text("Access pass for \(visitor.name)")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.brandPrimary)

                    Button {
                        UIPasteboard.general.string = visitor.accessToken
                    } label: {
                        Label("Copy Token", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding()
            .navigationTitle("Visitor Pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    VisitorsView()
}
