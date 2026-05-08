import SwiftUI
import UIKit

struct VisitorsView: View {
    @State private var viewModel = VisitorsViewModel()
    @State private var settings = SettingsService.shared

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.visitors.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        settings.L("visitors.empty"),
                        systemImage: "person.badge.plus",
                        description: Text(settings.L("visitors.empty_description"))
                    )
                } else {
                    visitorList
                }
            }
            .navigationTitle(settings.L("visitors.title"))
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
                await viewModel.fetchVisitorGroup()
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateVisitorView()
                    .environment(viewModel)
            }
            .sheet(item: $viewModel.createdVisitor) { visitor in
                VisitorQRView(visitor: visitor)
                    .environment(viewModel)
            }
        }
        .environment(viewModel)
    }

    private var visitorList: some View {
        List {
            if let group = viewModel.visitorGroup {
                visitorGroupSection(group: group)
            }

            if !viewModel.activeVisitors.isEmpty {
                Section(settings.L("visitors.active")) {
                    ForEach(viewModel.activeVisitors) { visitor in
                        VisitorRowView(visitor: visitor)
                    }
                }
            }

            if !viewModel.expiredVisitors.isEmpty {
                Section(settings.L("visitors.expired")) {
                    ForEach(viewModel.expiredVisitors) { visitor in
                        VisitorRowView(visitor: visitor)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func visitorGroupSection(group: VisitorGroup) -> some View {
        Section {
            HStack {
                Label(group.name, systemImage: "person.3.fill")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.activeGroupMembers.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            ForEach(viewModel.activeGroupMembers) { member in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.visitorName).font(.body)
                        Text(memberTimeRemaining(member.expiresAt))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(settings.L("profile.active"))
                        .font(.caption2).fontWeight(.medium)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green).clipShape(Capsule())
                }
            }

            if !viewModel.expiredGroupMembers.isEmpty {
                ForEach(viewModel.expiredGroupMembers) { member in
                    HStack {
                        Text(member.visitorName).font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(settings.L("visitors.expired"))
                            .font(.caption2).fontWeight(.medium)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red).clipShape(Capsule())
                    }
                }

                Button {
                    Task { await viewModel.cleanupExpired() }
                } label: {
                    Label(settings.L("visitors.cleanup_expired"), systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text(settings.L("visitors.temp_group"))
        } footer: {
            Text(settings.L("visitors.temp_group_desc"))
        }
    }

    private func memberTimeRemaining(_ expiresAt: Date) -> String {
        let interval = expiresAt.timeIntervalSinceNow
        guard interval > 0 else { return settings.L("visitors.expired") }
        let hours = Int(interval / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if hours > 0 {
            return String(format: settings.L("visitors.expires_in_hm"), hours, minutes)
        }
        return String(format: settings.L("visitors.expires_in_m"), minutes)
    }
}

struct VisitorRowView: View {
    let visitor: Visitor
    @Environment(VisitorsViewModel.self) private var viewModel
    @State private var showCopied = false
    private let settings = SettingsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(visitor.name)
                    .font(.headline)
                Spacer()
                if visitor.isExpired {
                    Text(settings.L("visitors.expired"))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else {
                    Text(settings.L("profile.active"))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }

            if !visitor.hostName.isEmpty {
                Text(visitor.hostName)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if !visitor.isExpired {
                Text(visitor.timeRemaining)
                    .font(.caption)
                    .foregroundStyle(.orange)

                HStack(spacing: 12) {
                    if let label = visitor.displayLabel {
                        Button {
                            UIPasteboard.general.string = label
                            showCopied = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                showCopied = false
                            }
                        } label: {
                            Label(showCopied ? settings.L("common.copied") : settings.L("visitors.copy_link"), systemImage: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        ShareLink(
                            item: label,
                            subject: Text(settings.L("visitors.pass_title")),
                            message: Text(String(format: settings.L("visitors.access_pass_for"), visitor.name))
                        ) {
                            Label(settings.L("visitors.share"), systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            viewModel.createdVisitor = visitor
                        } label: {
                            Label("QR", systemImage: "qrcode")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - QR Display

struct VisitorQRView: View {
    let visitor: Visitor
    @Environment(VisitorsViewModel.self) private var viewModel
    private let settings = SettingsService.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(visitor.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                if let label = visitor.displayLabel,
                   let qrData = viewModel.generateQRCode(from: label),
                   let uiImage = UIImage(data: qrData) {
                    Image(uiImage: uiImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("QR access code for visitor \(visitor.name)")
                }

                Text(visitor.timeRemaining)
                    .font(.callout)
                    .foregroundStyle(.orange)

                if let label = visitor.displayLabel {
                    HStack(spacing: 16) {
                        ShareLink(
                            item: label,
                            subject: Text(settings.L("visitors.pass_title")),
                            message: Text(String(format: settings.L("visitors.access_pass_for"), visitor.name))
                        ) {
                            Label(settings.L("visitors.share"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.brandPrimary)

                        Button {
                            UIPasteboard.general.string = label
                        } label: {
                            Label(settings.L("common.copy"), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .padding()
            .navigationTitle(settings.L("visitors.pass_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.L("common.done")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    VisitorsView()
}
