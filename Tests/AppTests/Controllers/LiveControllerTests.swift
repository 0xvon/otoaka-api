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
            $0.set(\.style, value: .oneman(performer: createdGroup.id))
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "lives", headers: appClient.makeHeaders(for: user), body: bodyData) {
            res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Endpoint.CreateLive.Response.self)
            XCTAssertEqual(responseBody.title, body.title)
        }
    }

    func testEditLive() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let groupX = try appClient.createGroup(with: userA)
        let live = try appClient.createLive(hostGroup: groupX, with: userA)
        let newTitle = "a new live title"
        let body = try! Stub.make(EditLive.Request.self) {
            $0.set(\.title, value: newTitle)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "lives/edit/\(live.id)", headers: appClient.makeHeaders(for: userA),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Endpoint.EditLive.Response.self)
            XCTAssertEqual(responseBody.title, newTitle)
        }

        try app.test(
            .POST, "lives/edit/\(live.id)", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .forbidden, res.body.string)
        }
    }

    func testCreateLiveAsNonHostMember() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "important")))
        let createdGroup = try appClient.createGroup(with: user)

        let nonMemberUser = try appClient.createUser()

        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: createdGroup.id)
            $0.set(\.style, value: .oneman(performer: createdGroup.id))
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
            $0.set(
                \.style, value: .battle(performers: [participatingGroup.id, participatingGroup.id]))
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
            hostGroup: hostGroup, style: .battle(performers: performers.map(\.id)), with: user)

        try app.test(.GET, "lives/\(live.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.CreateLive.Response.self)
            XCTAssertEqual(Set(performers.map(\.id)), Set(responseBody.style.performers.map(\.id)))
        }
    }

    func testRegisterLive() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let hostGroup = try appClient.createGroup(with: user)
        let live = try appClient.createLive(
            hostGroup: hostGroup, style: .battle(performers: []), with: user)

        let body = try! Stub.make(Endpoint.ReserveTicket.Request.self) {
            $0.set(\.liveId, value: live.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "lives/reserve", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.ReserveTicket.Response.self)
            XCTAssertEqual(responseBody.status, .registered)
        }
    }

    func testGetUpcomingLives() throws {
        let user = try appClient.createUser(role: .artist(.init(part: "vocal")))
        let hostGroup = try appClient.createGroup(with: user)
        _ = try appClient.createLive(hostGroup: hostGroup, with: user)

        let headers = appClient.makeHeaders(for: user)
        try app.test(.GET, "lives/upcoming?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(Endpoint.GetUpcomingLives.Response.self)
            XCTAssertGreaterThan(responseBody.items.count, 1)
        }
    }

    func testReplyRequestAccept() throws {
        let hostUser = try appClient.createUser(role: .artist(.init(part: "vocal")))
        let hostGroup = try appClient.createGroup(with: hostUser)

        let userX = try appClient.createUser(role: .artist(.init(part: "foo")))
        let groupA = try appClient.createGroup(with: userX)

        _ = try appClient.createLive(
            hostGroup: hostGroup, style: .battle(performers: [groupA.id]), with: hostUser
        )

        let requests = try appClient.getPerformanceRequests(with: userX)
        XCTAssertEqual(requests.items.count, 1)
        let receivedRequest = try XCTUnwrap(requests.items.first)
        XCTAssertEqual(receivedRequest.status, .pending)
        let body = try! Stub.make(ReplyPerformanceRequest.Request.self) {
            $0.set(\.reply, value: .accept)
            $0.set(\.requestId, value: receivedRequest.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        let headers = appClient.makeHeaders(for: userX)
        try app.test(.POST, "lives/reply", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }

        let updatedRequests = try appClient.getPerformanceRequests(with: userX)
        XCTAssertEqual(updatedRequests.items.first?.status, .accepted)
    }
}
