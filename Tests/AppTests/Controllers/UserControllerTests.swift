import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class UserControllerTests: XCTestCase {
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
        let signupBody = Endpoint.Signup.Request(name: dummyUserName, role: .fan(Fan()))
        let signupBodyData = try ByteBuffer(data: JSONEncoder().encode(signupBody))

        try app.test(.GET, "users/get_signup_status", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(SignupStatus.Response.self)
            XCTAssertFalse(responseBody.isSignedup)
        }
        try app.test(.POST, "users/signup", headers: headers, body: signupBodyData) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Signup.Response.self)
            XCTAssertEqual(responseBody.name, dummyUserName)
        }
        try app.test(.GET, "users/get_signup_status", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(SignupStatus.Response.self)
            XCTAssertTrue(responseBody.isSignedup)
        }

        // Try to create same id user again
        try app.test(.POST, "users/signup", headers: headers, body: signupBodyData) { res in
            XCTAssertEqual(res.status, .badRequest)
        }

        // Try to get user info after create user
        try app.test(.GET, "users/get_info", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Signup.Response.self)
            XCTAssertEqual(responseBody.name, dummyUserName)
        }

        let updatedName = UUID().uuidString
        let editBody = Endpoint.Signup.Request(name: updatedName, role: .fan(Fan()))
        let editBodyData = try ByteBuffer(data: JSONEncoder().encode(editBody))
        try app.test(.POST, "users/edit_user_info", headers: headers, body: editBodyData) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Signup.Response.self)
            XCTAssertEqual(responseBody.name, updatedName)
        }

        let changeRoleBody = Endpoint.EditUserInfo.Request(
            name: UUID().uuidString, role: .artist(try! Stub.make()))
        let changeRoleBodyData = try ByteBuffer(data: JSONEncoder().encode(changeRoleBody))
        try app.test(.POST, "users/edit_user_info", headers: headers, body: changeRoleBodyData) {
            res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testRegisterUserDeviceToken() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)

        let body = try! Stub.make(Endpoint.RegisterDeviceToken.Request.self) {
            $0.set(
                \.deviceToken,
                value: "78539a7548fecaa554e7e8a9d714e8bb23de234763534dd3cce071cbc3d353aa")
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "users/register_device_token", headers: headers, body: bodyData) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }

        try app.test(.POST, "users/register_device_token", headers: headers, body: bodyData) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }
}
