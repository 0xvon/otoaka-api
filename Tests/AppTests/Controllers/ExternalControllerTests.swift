import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class ExternalControllerTests: XCTestCase {
    var app: Application!
    var appClient: AppClient!
    override func setUp() {
        app = Application(.testing)
        DotEnvFile.load(path: dotEnvPath.path)
        XCTAssertNoThrow(try configure(app))
        appClient = AppClient(application: app, cognito: CognitoClient())
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCheckGlobalIP() throws {
        let user = try appClient.createUser()
        try app.test(
        .GET, "external/global_ip", headers: appClient.makeHeaders(for: user)) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }
    
    func testNotifyUpcomingLives() throws {
        let user = try appClient.createUser()
        try app.test(
            .GET, "external/notify_upcoming_lives", headers: appClient.makeHeaders(for: user)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }
}
