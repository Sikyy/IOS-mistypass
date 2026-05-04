import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

@MainActor @Observable
final class VisitorsViewModel {
    var visitors: [Visitor] = []
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var createdVisitor: Visitor?

    var activeVisitors: [Visitor] {
        visitors.filter { !$0.isExpired && $0.isActive }
    }

    var expiredVisitors: [Visitor] {
        visitors.filter { $0.isExpired || !$0.isActive }
    }

    func fetchVisitors() async {
        isLoading = true
        errorMessage = nil

        do {
            visitors = try await APIService.shared.fetchVisitors()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createVisitor(
        name: String,
        phone: String,
        hostName: String,
        company: String?,
        purpose: String?,
        doorIds: [String],
        ttlHours: Int
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let request = CreateVisitorRequest(
                name: name,
                phone: phone,
                hostName: hostName,
                company: company,
                purpose: purpose,
                doorIds: doorIds,
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

    /// Generate QR code image from access token
    func generateQRCode(from token: String) -> Data? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(token.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up for clarity
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.pngData()
    }
}
