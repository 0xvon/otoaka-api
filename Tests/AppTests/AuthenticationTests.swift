import XCTVapor
@testable import App

class AuthenticationTests: XCTestCase {
    var app: Application!
    override func setUp() {
        app = Application(.testing)
        XCTAssertNoThrow(try configure(app))
    }
    override func tearDown() {
        app.shutdown()
    }
    func testUnauthenticated() throws {
        let dotEnvPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".env.testing")
        DotEnvFile.load(path: dotEnvPath.path)

        try app.grouped(JWTAuthenticator()).get("secure") { _ in
            "Logged in"
        }
        try app.test(.GET, "secure") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }
}
