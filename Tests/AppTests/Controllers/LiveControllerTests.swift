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

    func testCreateLiveWithDuplicatedPerformers() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let hostGroup = try appClient.createGroup(with: user)

        let artist = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let request = try! Stub.make(Endpoint.CreateGroup.Request.self) {
            $0.set(\.name, value: UUID().uuidString)
        }
        let participatingGroup = try appClient.createGroup(body: request, with: artist)

        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: hostGroup.id)
            $0.set(\.performerGroupIds, value: [participatingGroup.id, participatingGroup.id])
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "lives", headers: headers, body: bodyData) { res in
            XCTAssertNotEqual(res.status, .ok)
        }
    }

    func testGetLive() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let hostGroup = try appClient.createGroup(with: user)
        var performers: [Endpoint.Group] = []

        for _ in 0..<3 {
            let artist = try appClient.createUser(role: .artist(Artist(part: "vocal")))
            let request = try! Stub.make(Endpoint.CreateGroup.Request.self) {
                $0.set(\.name, value: UUID().uuidString)
            }
            let group = try appClient.createGroup(body: request, with: artist)
            performers.append(group)
        }

        let live = try appClient.createLive(
            hostGroup: hostGroup, performers: performers, with: user)

        try app.test(.GET, "lives/\(live.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.CreateLive.Response.self)
            XCTAssertEqual(Set(performers.map(\.id)), Set(responseBody.performers.map(\.id)))
        }
    }

    func testRegisterLive() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let hostGroup = try appClient.createGroup(with: user)
        let live = try appClient.createLive(hostGroup: hostGroup, performers: [], with: user)

        let body = try! Stub.make(Endpoint.RegisterLive.Request.self) {
            $0.set(\.liveId, value: live.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "lives/register", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.RegisterLive.Response.self)
            XCTAssertEqual(responseBody.status, .registered)
        }
    }
}
