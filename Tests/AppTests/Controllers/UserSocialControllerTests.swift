import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class UserSocialControllerTests: XCTestCase {
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

    func testFollow() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let body = try! Stub.make(Endpoint.FollowGroup.Request.self) {
            $0.set(\.id, value: groupX.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/follow_group", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testUnfollow() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)

        try appClient.follow(group: groupX, with: userB)

        let body = try! Stub.make(Endpoint.UnfollowGroup.Request.self) {
            $0.set(\.id, value: groupX.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/unfollow_group", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testGetFollowings() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let groupY = try appClient.createGroup(with: userA)

        try appClient.follow(group: groupX, with: userB)
        try appClient.follow(group: groupY, with: userB)

        try app.test(
            .GET, "user_social/following_groups/\(userB.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(FollowingGroups.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }

    func testGetFollowers() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)

        try appClient.follow(group: groupX, with: userB)
        try appClient.follow(group: groupX, with: userA)

        try app.test(
            .GET, "user_social/group_followers/\(groupX.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(GroupFollowers.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }
}