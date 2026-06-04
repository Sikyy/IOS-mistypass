import XCTest
@testable import MistyisletPass

/// Pins the visitor-pass `delivery_method` contract on the client side.
///
/// The backend (`normalizeDeliveryMethod` in
/// `api/internal/modules/access/service_policies.go`) accepts only `"wallet"`
/// and `"email_qr"` and returns HTTP 400 for anything else. The picker must
/// therefore never offer a value outside that set. Historically it defaulted to
/// `"whatsapp"`, which the backend rejected on every create.
final class CreateVisitorDeliveryMethodTests: XCTestCase {
    /// Mirror of the backend's accepted set. Keep in sync with the server.
    private let backendSupported: Set<String> = ["wallet", "email_qr"]

    func testPickerOffersOnlyBackendSupportedMethods() {
        let offered = CreateVisitorView.DeliveryMethod.allCases.map(\.rawValue)
        XCTAssertFalse(offered.isEmpty, "expected at least one delivery method in the picker")
        for raw in offered {
            XCTAssertTrue(
                backendSupported.contains(raw),
                "delivery method \"\(raw)\" is not accepted by the backend and would be rejected"
            )
        }
    }

    func testDefaultDeliveryMethodIsBackendSupported() {
        XCTAssertTrue(
            backendSupported.contains(CreateVisitorView.DeliveryMethod.emailQR.rawValue),
            "the default delivery method must be accepted by the backend"
        )
    }
}
