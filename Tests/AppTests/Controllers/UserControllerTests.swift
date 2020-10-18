@testable import App
import Domain
import Endpoint
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
        try app.test(.POST, "users/signup") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
        let client = CognitoClient()
        let dummyCognitoUserName = UUID().uuidString
        let dummyUser = try client.createToken(userName: dummyCognitoUserName).wait()
        defer { try! client.destroyUser(userName: dummyCognitoUserName).wait() }


        var headers = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(dummyUser.token)")
        headers.add(name: .contentType, value: HTTPMediaType.json.serialize())

        // Try to get user info before create user
        try app.test(.GET, "users/get_info", headers: headers) { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        let dummyUserName = UUID().uuidString
        let body = Endpoint.Signup.Request(name: dummyUserName, role: .fan(Fan()))
        let bodyData = try ByteBuffer(data: JSONEncoder().encode(body))

        try app.test(.POST, "users/signup", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Signup.Response.self)
            XCTAssertEqual(responseBody.name, dummyUserName)
        }

        // Try to create same id user again
        try app.test(.POST, "users/signup", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .badRequest)
        }

        // Try to get user info after create user
        try app.test(.GET, "users/get_info", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Signup.Response.self)
            XCTAssertEqual(responseBody.name, dummyUserName)
        }
    }
}
