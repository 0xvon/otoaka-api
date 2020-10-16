@testable import App
import Domain
import XCTVapor

class UserControllerTests: XCTestCase {
    var app: Application!
    override func setUp() {
        app = Application(.testing)
        DotEnvFile.load(path: dotEnvPath.path)
        XCTAssertNoThrow(try configure(app))
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCreateUserAndGetUserInfo() throws {
        try app.test(.POST, "users/create") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
        let client = CognitoClient(httpClient: app.http.client.shared)
        let dummyUserName = UUID().uuidString
        let dummyUser = try client.createToken(userName: dummyUserName).wait()
        defer { try! client.destroyUser(userName: dummyUserName).wait() }


        var headers = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(dummyUser.token)")

        // Try to get user info before create user
        try app.test(.GET, "users/get_info", headers: headers) { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        try app.test(.POST, "users/create", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Domain.User.self)
            XCTAssertEqual(responseBody.id, User.ForeignID(value: dummyUser.sub))
        }

        // Try to create same id user again
        try app.test(.POST, "users/create", headers: headers) { res in
            XCTAssertEqual(res.status, .badRequest)
        }

        // Try to get user info after create user
        try app.test(.GET, "users/get_info", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Domain.User.self)
            XCTAssertEqual(responseBody.id, User.ForeignID(value: dummyUser.sub))
        }
    }
}
