import XCTest
@testable import MistyisletPass

@MainActor
final class AuthViewModelTests: XCTestCase {

    private var viewModel: AuthViewModel!

    override func setUp() {
        super.setUp()
        viewModel = AuthViewModel()
        viewModel.resetFlow()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialFlowState() {
        XCTAssertEqual(viewModel.authStep, .emailEntry)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.magicLinkSent)
        XCTAssertTrue(viewModel.email.isEmpty)
        XCTAssertTrue(viewModel.orgDomain.isEmpty)
        XCTAssertNil(viewModel.orgConfig)
    }

    // MARK: - Navigation Flow

    func testGoToManualSignIn() {
        viewModel.goToManualSignIn()
        XCTAssertEqual(viewModel.authStep, .domainEntry)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSkipDomain() {
        viewModel.authStep = .domainEntry
        viewModel.skipDomain()
        XCTAssertEqual(viewModel.authStep, .credentials)
        XCTAssertNil(viewModel.orgConfig)
    }

    func testGoBackFromDomainToEmail() {
        viewModel.authStep = .domainEntry
        viewModel.goBack()
        XCTAssertEqual(viewModel.authStep, .emailEntry)
    }

    func testGoBackFromCredentialsToDomain() {
        viewModel.authStep = .credentials
        viewModel.goBack()
        XCTAssertEqual(viewModel.authStep, .domainEntry)
    }

    func testGoBackFromMagicLinkToEmail() {
        viewModel.authStep = .magicLinkSent
        viewModel.magicLinkSent = true
        viewModel.goBack()
        XCTAssertEqual(viewModel.authStep, .emailEntry)
        XCTAssertFalse(viewModel.magicLinkSent)
    }

    func testGoBackFromEmailDoesNothing() {
        viewModel.authStep = .emailEntry
        viewModel.goBack()
        XCTAssertEqual(viewModel.authStep, .emailEntry)
    }

    func testGoBackClearsError() {
        viewModel.authStep = .domainEntry
        viewModel.errorMessage = "Some error"
        viewModel.goBack()
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Reset Flow

    func testResetFlowClearsEverything() {
        viewModel.authStep = .credentials
        viewModel.email = "test@example.com"
        viewModel.orgDomain = "example.com"
        viewModel.magicLinkSent = true
        viewModel.errorMessage = "Error"

        viewModel.resetFlow()

        XCTAssertEqual(viewModel.authStep, .emailEntry)
        XCTAssertTrue(viewModel.email.isEmpty)
        XCTAssertTrue(viewModel.orgDomain.isEmpty)
        XCTAssertNil(viewModel.orgConfig)
        XCTAssertFalse(viewModel.magicLinkSent)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Logout

    func testLogoutClearsState() {
        viewModel.logout()
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertNil(viewModel.user)
        XCTAssertEqual(viewModel.authStep, .emailEntry)
    }

    // MARK: - Guard Checks

    func testRequestMagicLinkEmptyEmailDoesNothing() async {
        viewModel.email = ""
        await viewModel.requestMagicLink()
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.authStep, .emailEntry)
    }

    func testLookupOrgEmptyDomainDoesNothing() async {
        viewModel.orgDomain = ""
        await viewModel.lookupOrganization()
        XCTAssertFalse(viewModel.isLoading)
    }
}
