import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class GroupControllerTests: XCTestCase {
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

    func testUpdateGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let createdGroup = try appClient.createGroup(with: user)
        let newName = "a new group name"
        let body = try! Stub.make(EditGroup.Request.self) {
            $0.set(\.name, value: newName)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        try app.test(
            .POST, "groups/edit/\(createdGroup.id)", headers: appClient.makeHeaders(for: user),
            body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(EditGroup.Request.self)
            XCTAssertEqual(body.name, newName)
        }
    }

    func testInviteForNonExistingGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let body = try! Stub.make(InviteGroup.Request.self)
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        try app.test(
            .POST, "groups/invite", headers: appClient.makeHeaders(for: user),
            body: bodyData
        ) { res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }
    }

    func testInviteForNonMemberGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let createdGroup = try appClient.createGroup(with: user)
        let nonMemberUser = try appClient.createUser()

        let body = try! Stub.make(InviteGroup.Request.self) {
            $0.set(\.groupId, value: createdGroup.id)
        }

        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        // Try to create an invitation for non-member group
        try app.test(
            .POST, "groups/invite", headers: appClient.makeHeaders(for: nonMemberUser),
            body: bodyData
        ) { res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }
    }

    func testGetGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let createdGroup = try appClient.createGroup(with: user)

        try app.test(.GET, "groups/\(createdGroup.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testGetAllGroup() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        _ = try appClient.createGroup(with: user)
        _ = try appClient.createGroup(with: user)
        _ = try appClient.createGroup(with: user)

        try app.test(.GET, "groups?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetAllGroups.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 3)
        }
    }

    func testGetMemberships() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupA = try appClient.createGroup(with: user)
        let groupB = try appClient.createGroup(with: user)

        try app.test(.GET, "groups/memberships/\(user.user.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetMemberships.Response.self)
            XCTAssertEqual(Set(response.map(\.id)), Set([groupA.id, groupB.id]))
        }
    }

    func testJoinWithInvalidInvitation() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        _ = try appClient.createGroup(with: user)

        let body = try! Stub.make(JoinGroup.Request.self) {
            let fakeInvitation = UUID()
            $0.set(\.invitationId, value: fakeInvitation.uuidString)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        // Try to join with invalid invitation
        try app.test(.POST, "groups/join", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testJoinTwice() throws {
        // try to create without login
        try app.test(.POST, "groups") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let encoder = appClient.encoder

        let headers = appClient.makeHeaders(for: user)
        let createdGroup = try appClient.createGroup(with: user)
        let createdInvitation = try appClient.createInvitation(group: createdGroup, with: user)

        let body = try! Stub.make(JoinGroup.Request.self) {
            $0.set(\.invitationId, value: createdInvitation.id)
        }
        let bodyData = try ByteBuffer(data: encoder.encode(body))
        try app.test(.POST, "groups/join", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok)
            _ = try res.content.decode(JoinGroup.Response.self)
        }

        // Try to join again with the same invitation
        try app.test(.POST, "groups/join", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testCreateGroupFeed() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupX = try appClient.createGroup(with: user)

        let body = try! Stub.make(Endpoint.CreateGroupFeed.Request.self) {
            $0.set(\.groupId, value: groupX.id)
            $0.set(\.feedType, value: .youtube(try! Stub.make()))
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "groups/create_feed", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.CreateGroupFeed.Response.self)
            XCTAssertEqual(responseBody.group.id, groupX.id)
        }
    }

    func testGetGroupFeeds() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupX = try appClient.createGroup(with: user)
        let feed = try appClient.createGroupFeed(group: groupX, with: user)

        try app.test(.GET, "groups/\(groupX.id)/feeds?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetGroupFeed.Response.self)
            let firstItem = try XCTUnwrap(responseBody.items.first)
            XCTAssertEqual(firstItem.id, feed.id)
        }
    }
}
