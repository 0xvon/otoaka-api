import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class LiveControllerTests: XCTestCase {
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

    func testCreateWithoutLogin() throws {
        try app.test(.POST, "lives") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testCreateLive() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let createdGroup = try appClient.createGroup(with: user)
        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: createdGroup.id)
            $0.set(\.performerGroupIds, value: [createdGroup.id])
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "lives", headers: appClient.makeHeaders(for: user), body: bodyData) {
            res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Endpoint.CreateLive.Response.self)
            XCTAssertEqual(responseBody.title, body.title)
        }
    }

    func testCreateLiveAsNonHostMember() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "important")))
        let createdGroup = try appClient.createGroup(with: user)

        let nonMemberUser = try appClient.createUser()

        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: createdGroup.id)
            $0.set(\.performerGroupIds, value: [createdGroup.id])
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        let headers = appClient.makeHeaders(for: nonMemberUser)

        try app.test(.POST, "lives", headers: headers, body: bodyData) { res in
            XCTAssertNotEqual(res.status, .ok)
        }
    }
}
