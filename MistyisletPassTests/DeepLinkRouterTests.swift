import XCTest
@testable import MistyisletPass

@MainActor
final class DeepLinkRouterTests: XCTestCase {

    var router: DeepLinkRouter!

    override func setUp() {
        router = DeepLinkRouter.shared
        router.clearPending()
    }

    override func tearDown() async throws {
        router.clearPending()
        router = nil
    }

    func testUnlockDeepLink() {
        let url = URL(string: "mistyislet://unlock/door-001")!
        router.handle(url: url)
        XCTAssertEqual(router.pendingTab, 0)
        XCTAssertEqual(router.pendingDoorId, "door-001")
    }

    func testPassDeepLink() {
        let url = URL(string: "mistyislet://pass")!
        router.handle(url: url)
        XCTAssertEqual(router.pendingTab, 1)
    }

    func testHistoryDeepLink() {
        let url = URL(string: "mistyislet://history")!
        router.handle(url: url)
        XCTAssertEqual(router.pendingTab, 2)
    }

    func testVisitorsDeepLink() {
        let url = URL(string: "mistyislet://visitors")!
        router.handle(url: url)
        XCTAssertEqual(router.pendingTab, 3)
    }

    func testProfileDeepLink() {
        let url = URL(string: "mistyislet://profile")!
        router.handle(url: url)
        XCTAssertEqual(router.pendingTab, 3)
    }

    func testVisitorUniversalLink() {
        let url = URL(string: "https://app.mistyislet.com/visitor/token-abc-123")!
        router.handle(url: url)
        XCTAssertEqual(router.pendingTab, 3)
        XCTAssertEqual(router.pendingVisitorToken, "token-abc-123")
    }

    func testClearPending() {
        router.pendingTab = 2
        router.pendingDoorId = "door-001"
        router.clearPending()
        XCTAssertNil(router.pendingTab)
        XCTAssertNil(router.pendingDoorId)
        XCTAssertNil(router.pendingVisitorToken)
    }
}
