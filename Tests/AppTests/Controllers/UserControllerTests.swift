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
    
    func testGetUserDetail() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let header = appClient.makeHeaders(for: userB)
        let groupX = try appClient.createGroup(with: userA)
        _ = try appClient.createUserFeed(with: userA, groupId: groupX.id)
        _ = try appClient.followUser(target: userA, with: userB)

        try app.test(.GET, "users/\(userA.user.id)", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserDetail.Response.self)
            XCTAssertTrue(response.isFollowing)
            XCTAssertFalse(response.isFollowed)
            XCTAssertEqual(response.feedCount, 1)
        }
        
        try app.test(.GET, "users/\(userB.user.id)", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserDetail.Response.self)
            XCTAssertFalse(response.isFollowing)
            XCTAssertFalse(response.isFollowed)
            XCTAssertEqual(response.feedCount, 0)
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
    
    func testCreateUserFeed() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupX = try appClient.createGroup(with: user)

        let body = try! Stub.make(Endpoint.CreateUserFeed.Request.self) {
            $0.set(\.feedType, value: .youtube(try! Stub.make()))
            $0.set(\.groupId, value: groupX.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "users/create_feed", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.CreateUserFeed.Response.self)
            XCTAssertEqual(responseBody.author.id, user.user.id)
        }
    }

    func testDeleteUserFeeds() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupX = try appClient.createGroup(with: user)
        let feed = try appClient.createUserFeed(with: user, groupId: groupX.id)
        let _ = try appClient.createUserFeed(with: user, groupId: groupX.id)
        let _ = try appClient.likeUserFeed(feed: feed, with: user)
        let _ = try appClient.commentUserFeed(feed: feed, with: user)
        let body = try! Stub.make(DeleteUserFeed.Request.self) {
            $0.set(\.id, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        
        try app.test(.GET, "user_social/liked_user_feeds/\(user.user.id)?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetLikedUserFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
        
        try app.test(.GET, "user_social/user_feed_comment/\(feed.id)?page=1&per=200", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetUserFeedComments.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
        
        try app.test(.GET, "users/\(user.user.id)/feeds?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetUserFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
        }

        try app.test(.DELETE, "users/delete_feed", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }

        // try to delete twice
        try app.test(.DELETE, "users/delete_feed", headers: headers, body: bodyData) { res in
            XCTAssertNotEqual(res.status, .ok, res.body.string)
        }
        
        try app.test(.GET, "user_social/liked_user_feeds/\(user.user.id)?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetLikedUserFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 0)
        }
        
        try app.test(.GET, "user_social/user_feed_comment/\(feed.id)?page=1&per=200", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetUserFeedComments.Response.self)
            XCTAssertEqual(responseBody.items.count, 0)
        }

        try app.test(.GET, "users/\(user.user.id)/feeds?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetUserFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }

    func testGetUserFeeds() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let groupX = try appClient.createGroup(with: user)
        let feed = try appClient.createUserFeed(with: user, groupId: groupX.id)

        try app.test(.GET, "users/\(user.user.id)/feeds?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetUserFeeds.Response.self)
            let firstItem = try XCTUnwrap(responseBody.items.first)
            XCTAssertEqual(firstItem.id, feed.id)
            XCTAssertEqual(firstItem.commentCount, 0)
        }
    }

    func testPostCommentOnUserFeed() throws {
        let userX = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userY = try appClient.createUser(role: .fan(.init()))
        let groupX = try appClient.createGroup(with: userX)
        let feed = try appClient.createUserFeed(with: userX, groupId: groupX.id)

        let body = try! Stub.make(Endpoint.PostUserFeedComment.Request.self) {
            $0.set(\.feedId, value: feed.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        let headers = appClient.makeHeaders(for: userY)
        try app.test(.POST, "user_social/user_feed_comment", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.PostUserFeedComment.Response.self)
            XCTAssertEqual(responseBody.author.id, userY.user.id)
        }

        try app.test(.GET, "user_social/user_feed_comment/\(feed.id)?page=1&per=10", headers: headers) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetUserFeedComments.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }
}
