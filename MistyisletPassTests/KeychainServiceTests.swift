import XCTest
@testable import MistyisletPass

final class KeychainServiceTests: XCTestCase {

    private let testKey = "com.mistyislet.test.key"

    override func tearDown() {
        try? KeychainService.shared.delete(forKey: testKey)
        super.tearDown()
    }

    func testSaveAndReadString() throws {
        try KeychainService.shared.save("test-token-123", forKey: testKey)
        let result = KeychainService.shared.readString(forKey: testKey)
        XCTAssertEqual(result, "test-token-123")
    }

    func testSaveAndReadData() throws {
        let data = "binary-data".data(using: .utf8)!
        try KeychainService.shared.save(data, forKey: testKey)
        let result = KeychainService.shared.read(forKey: testKey)
        XCTAssertEqual(result, data)
    }

    func testReadNonExistentKey() {
        let result = KeychainService.shared.readString(forKey: "com.mistyislet.nonexistent")
        XCTAssertNil(result)
    }

    func testOverwrite() throws {
        try KeychainService.shared.save("value-1", forKey: testKey)
        try KeychainService.shared.save("value-2", forKey: testKey)
        let result = KeychainService.shared.readString(forKey: testKey)
        XCTAssertEqual(result, "value-2")
    }

    func testDelete() throws {
        try KeychainService.shared.save("to-delete", forKey: testKey)
        try KeychainService.shared.delete(forKey: testKey)
        let result = KeychainService.shared.readString(forKey: testKey)
        XCTAssertNil(result)
    }

    func testDeleteNonExistent() {
        XCTAssertNoThrow(try KeychainService.shared.delete(forKey: "com.mistyislet.nonexistent"))
    }
}
