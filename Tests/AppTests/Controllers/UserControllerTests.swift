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
        let signupBody = Endpoint.Signup.Request(
            name: dummyUserName,
            biography: try! Stub.make(),
            sex: try! Stub.make(),
            age: try! Stub.make(),
            liveStyle: try! Stub.make(),
            residence: try! Stub.make(),
            thumbnailURL: try! Stub.make(),
            role: .fan(Fan()),
            twitterUrl: try! Stub.make(),
            instagramUrl: try! Stub.make()
        )
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
        let editBody = Endpoint.Signup.Request(
            name: updatedName,
            biography: try! Stub.make(),
            sex: try! Stub.make(),
            age: try! Stub.make(),
            liveStyle: try! Stub.make(),
            residence: try! Stub.make(),
            thumbnailURL: try! Stub.make(),
            role: .fan(Fan()),
            twitterUrl: try! Stub.make(),
            instagramUrl: try! Stub.make()
        )
        let editBodyData = try ByteBuffer(data: JSONEncoder().encode(editBody))
        try app.test(.POST, "users/edit_user_info", headers: headers, body: editBodyData) { res in
            XCTAssertEqual(res.status, .ok)
            let responseBody = try res.content.decode(Signup.Response.self)
            XCTAssertEqual(responseBody.name, updatedName)
        }

        let changeRoleBody = Endpoint.EditUserInfo.Request(
            name: UUID().uuidString,
            biography: try! Stub.make(),
            sex: try! Stub.make(),
            age: try! Stub.make(),
            liveStyle: try! Stub.make(),
            residence: try! Stub.make(),
            thumbnailURL: try! Stub.make(),
            role: .artist(try! Stub.make()),
            twitterUrl: try! Stub.make(),
            instagramUrl: try! Stub.make()
        )
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
            XCTAssertEqual(response.followersCount, 1)
        }
        
        try app.test(.GET, "users/\(userB.user.id)", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserDetail.Response.self)
            XCTAssertFalse(response.isFollowing)
            XCTAssertFalse(response.isFollowed)
            XCTAssertEqual(response.feedCount, 0)
            XCTAssertEqual(response.followingUsersCount, 1)
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
        
        try app.test(.GET, "users/feeds/\(feed.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetUserFeed.Response.self)
            XCTAssertEqual(responseBody.id, feed.id)
        }
    }
    
    func testCreatePost() throws {
        let user = try appClient.createUser()
        let headers = appClient.makeHeaders(for: user)

        // create 2 posts
        let post = try appClient.createPost(with: user)
        _ = try appClient.createPost(with: user)

        try app.test(.GET, "users/\(user.user.id)/posts?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetPosts.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
            XCTAssertEqual(responseBody.items.first!.groups.count, 2)
            XCTAssertEqual(responseBody.items.first!.imageUrls.count, 2)
        }
        
        // edit 1 post
        _ = try appClient.editPost(with: user, post: post)

        // delete 1 post
        _ = try appClient.deletePost(postId: post.id, with: user)

        try app.test(.GET, "users/\(user.user.id)/posts?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetPosts.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
        
        let group = try appClient.createGroup(with: user)
        let live = try appClient.createLive(hostGroup: group, with: user)
        _ = try appClient.createPost(with: user, groups: [group], live: live)
        _ = try appClient.createPost(with: user, live: live)
        try app.test(.GET, "groups/\(group.id)/posts?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetGroupPosts.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
            XCTAssertTrue(responseBody.items.first!.live?.id == live.id)
        }
    }
    
    func testGetPost() throws {
        let user = try appClient.createUser()
        let headers = appClient.makeHeaders(for: user)

        // create 2 posts
        let post = try appClient.createPost(with: user)
        
        try app.test(.GET, "users/posts/\(post.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetPost.Response.self)
            XCTAssertEqual(responseBody.post.id, post.id)
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
    
    func testGetNotifications() throws {
        let userX = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userY = try appClient.createUser(role: .fan(.init()))
        let groupX = try appClient.createGroup(with: userX)
        let feed = try appClient.createUserFeed(with: userX, groupId: groupX.id)
        let post = try appClient.createPost(with: userX)
        let _ = try appClient.followUser(target: userX, with: userY) // notify
        let headers = appClient.makeHeaders(for: userX)
        
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
            XCTAssertFalse(responseBody.items.first!.isRead)
            
            let readNotiBody = Endpoint.ReadNotification.Request(notificationId: responseBody.items.first!.id)
            let readNotiBodyData = try ByteBuffer(data: appClient.encoder.encode(readNotiBody))

            try app.test(.POST, "users/read_notification", headers: headers, body: readNotiBodyData) { res in
                XCTAssertEqual(res.status, .ok, res.body.string)
            }
        }
        
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
            XCTAssertTrue(responseBody.items.first!.isRead)
        }
        
        let _ = try appClient.likeUserFeed(feed: feed, with: userY)
        let _ = try appClient.commentUserFeed(feed: feed, with: userY)

        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 3)
        }
        
        // unfollow user → delete notification
        let _ = try appClient.unfollowUser(target: userX, with: userY)
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
        }
        
        // unlike user feed → delete notification
        let _ = try appClient.unlikeUserFeed(feed: feed, with: userY)
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
        
        // delete user feed -> delete all notification about this feed
        let _ = try appClient.deleteUserFeed(feed: feed, with: userX)
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 0)
        }
        
        let _ = try appClient.likePost(post: post, with: userY)
        let _ = try appClient.commentPost(post: post, with: userY)

        // like and comment to post → add 2 notifications
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
        }
        
        // unlike post → delete notification
        _ = try appClient.unlikePost(post: post, with: userY)
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
        
        // delete post -> delete all notification about this post
        _ = try appClient.deletePost(postId: post.id, with: userX)
        try app.test(.GET, "users/notifications?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetNotifications.Response.self)
            XCTAssertEqual(responseBody.items.count, 0)
        }
    }
    
    func testPostCommentOnPost() throws {
        let userX = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userY = try appClient.createUser(role: .fan(.init()))
        let post = try appClient.createPost(with: userX)

        let body = try! Stub.make(Endpoint.AddPostComment.Request.self) {
            $0.set(\.postId, value: post.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        let headers = appClient.makeHeaders(for: userY)
        try app.test(.POST, "user_social/add_post_comment", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.AddPostComment.Response.self)
            XCTAssertEqual(responseBody.author.id, userY.user.id)
        }

        try app.test(.GET, "user_social/post_comments/\(post.id)?page=1&per=10", headers: headers) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetPostComments.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
        
        
    }
}
