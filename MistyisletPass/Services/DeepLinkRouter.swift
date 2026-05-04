import Foundation
import SwiftUI

/// Handles deep links from:
/// - URL scheme: mistyislet://unlock/{doorId}
/// - Universal links: https://app.mistyislet.com/visitor/{token}
/// - Widget taps
/// - Push notification actions
@MainActor @Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    var pendingTab: Int?
    var pendingDoorId: String?
    var pendingVisitorToken: String?

    private init() {}

    /// Parse a URL and route to the appropriate screen
    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

        if url.scheme == "mistyislet" {
            handleCustomScheme(components)
        } else {
            handleUniversalLink(components)
        }
    }

    private func handleCustomScheme(_ components: URLComponents) {
        guard let host = components.host else { return }

        switch host {
        case "unlock":
            // mistyislet://unlock/{doorId}
            let doorId = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !doorId.isEmpty {
                pendingDoorId = doorId
                pendingTab = 0 // Doors tab
            }

        case "pass":
            // mistyislet://pass
            pendingTab = 1

        case "history":
            // mistyislet://history
            pendingTab = 2

        case "visitors":
            // mistyislet://visitors
            pendingTab = 3

        case "profile":
            // mistyislet://profile
            pendingTab = 4

        default:
            break
        }
    }

    private func handleUniversalLink(_ components: URLComponents) {
        let pathComponents = components.path.split(separator: "/")

        if pathComponents.count >= 2 && pathComponents[0] == "visitor" {
            // https://app.mistyislet.com/visitor/{token}
            pendingVisitorToken = String(pathComponents[1])
            pendingTab = 3 // Visitors tab
        }
    }

    func clearPending() {
        pendingTab = nil
        pendingDoorId = nil
        pendingVisitorToken = nil
    }
}
