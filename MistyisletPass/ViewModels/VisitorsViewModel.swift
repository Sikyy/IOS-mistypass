import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

@MainActor @Observable
final class VisitorsViewModel {
    var visitors: [Visitor] = []
    var visitorGroup: VisitorGroup?
    var groupMembers: [VisitorGroupMember] = []
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var createdVisitor: Visitor?
    var placeId: String?

    var activeVisitors: [Visitor] {
        visitors.filter { !$0.isExpired && $0.isActive }
    }

    var expiredVisitors: [Visitor] {
        visitors.filter { $0.isExpired || !$0.isActive }
    }

    var activeGroupMembers: [VisitorGroupMember] {
        groupMembers.filter { !$0.isExpired && $0.isActive }
    }

    var expiredGroupMembers: [VisitorGroupMember] {
        groupMembers.filter { $0.isExpired || !$0.isActive }
    }

    func fetchVisitors() async {
        guard !Constants.AppEnvironment.isPreview else { return }
        isLoading = true
        errorMessage = nil

        do {
            visitors = try await APIService.shared.fetchVisitors()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func fetchVisitorGroup() async {
        guard let placeId else { return }
        do {
            let groups = try await APIService.shared.fetchVisitorGroups(placeId: placeId)
            visitorGroup = groups.first
            if let group = visitorGroup {
                groupMembers = try await APIService.shared.fetchVisitorGroupMembers(
                    placeId: placeId, groupId: group.id
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            if visitorGroup == nil {
                visitorGroup = VisitorGroup(
                    id: "vg-1", name: "Temporary Visitors", placeId: placeId,
                    memberCount: 3, autoRemoveExpired: true, createdAt: Date()
                )
                groupMembers = [
                    VisitorGroupMember(id: "vgm-1", visitorId: "v-1", visitorName: "Alice Johnson",
                                       expiresAt: Date().addingTimeInterval(3600), isActive: true),
                    VisitorGroupMember(id: "vgm-2", visitorId: "v-2", visitorName: "Bob Chen",
                                       expiresAt: Date().addingTimeInterval(7200), isActive: true),
                    VisitorGroupMember(id: "vgm-3", visitorId: "v-3", visitorName: "Carol Smith",
                                       expiresAt: Date().addingTimeInterval(-1800), isActive: false),
                ]
            }
            #endif
        }
    }

    func cleanupExpired() async {
        guard let placeId, let group = visitorGroup else { return }
        do {
            _ = try await APIService.shared.cleanupExpiredVisitors(placeId: placeId, groupId: group.id)
            groupMembers.removeAll { $0.isExpired }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createVisitor(
        name: String,
        ttlHours: Double = 24,
        deliveryMethod: String = "whatsapp",
        buildingId: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let request = CreateVisitorRequest(
                visitor: name,
                deliveryMethod: deliveryMethod,
                buildingId: buildingId,
                validFrom: nil,
                validUntil: nil,
                ttlHours: ttlHours
            )
            let visitor = try await APIService.shared.createVisitor(request)
            createdVisitor = visitor
            visitors.insert(visitor, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func generateQRCode(from token: String) -> Data? {
        QRGenerator.generate(from: token)?.pngData()
    }
}
