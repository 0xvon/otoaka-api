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
        let userC = try appClient.createUser()
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
        
        try app.test(
            .GET, "user_social/following_groups/\(userC.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(FollowingGroups.Response.self)
            XCTAssertEqual(body.items.count, 0)
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
    
    func testFollowUser() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let body = try! Stub.make(Endpoint.FollowUser.Request.self) {
            $0.set(\.id, value: userA.user.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/follow_user", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testUnfollowUser() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()

        try appClient.followUser(target: userA, with: userB)

        let body = try! Stub.make(Endpoint.UnfollowUser.Request.self) {
            $0.set(\.id, value: userA.user.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/unfollow_user", headers: appClient.makeHeaders(for: userB),
            body: bodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }
    
    func testBlockUser() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        
        let blockUserBody = try! Stub.make(Endpoint.BlockUser.Request.self) {
            $0.set(\.id, value: userA.user.id)
        }
        let blockUserBodyData = try ByteBuffer(data: appClient.encoder.encode(blockUserBody))
        
        let unblockUserBody = try! Stub.make(Endpoint.UnblockUser.Request.self) {
            $0.set(\.id, value: userA.user.id)
        }
        let unblockUserBodyData = try ByteBuffer(data: appClient.encoder.encode(unblockUserBody))

        try app.test(
            .POST, "user_social/block_user", headers: appClient.makeHeaders(for: userB),
            body: blockUserBodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
        
        try app.test(
            .GET, "users/\(userA.user.id)", headers: appClient.makeHeaders(for: userB)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserDetail.Response.self)
            XCTAssertTrue(response.isBlocking)
        }
        
        try app.test(
            .POST, "user_social/unblock_user", headers: appClient.makeHeaders(for: userB),
            body: unblockUserBodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
        
        try app.test(
            .GET, "users/\(userA.user.id)", headers: appClient.makeHeaders(for: userB)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserDetail.Response.self)
            XCTAssertFalse(response.isBlocking)
        }
        
        _ = try appClient.followUser(target: userA, with: userB)
        _ = try appClient.blockUser(target: userA, with: userB)
        
        try app.test(
            .GET, "users/\(userA.user.id)", headers: appClient.makeHeaders(for: userB)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserDetail.Response.self)
            XCTAssertTrue(response.isBlocking)
            XCTAssertFalse(response.isFollowing)
        }
    }
    
    func testGetFollowingUsers() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser(role: .artist(Artist(part: "bass")))

        try appClient.followUser(target: userB, with: userA)
        try appClient.followUser(target: userC, with: userA)

        try app.test(
            .GET, "user_social/following_users/\(userA.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(FollowingUsers.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }
    
    func testGetRecommendedUsers() throws {
        let userA = try appClient.createUser()
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        let userD = try appClient.createUser()
        _ = try appClient.createUser()
        _ = try appClient.createUser()
        
        _ = try appClient.followUser(target: userB, with: userA)
        
        try app.test(
            .GET,
            "user_social/recommended_users/\(userA.user.id)?page=1&per=10000000",
            headers: appClient.makeHeaders(for: userA)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(RecommendedUsers.Response.self)
            XCTAssertGreaterThanOrEqual(body.items.count, 5)
            let uids = body.items.map { $0.id }
            XCTAssertFalse(uids.contains(userA.user.id))
            XCTAssertFalse(uids.contains(userB.user.id))
            XCTAssertTrue(uids.contains(userC.user.id))
            XCTAssertTrue(uids.contains(userD.user.id))
        }
        
        _ = try appClient.blockUser(target: userD, with: userA)
        
        try app.test(
            .GET,
            "user_social/recommended_users/\(userA.user.id)?page=1&per=10000000",
            headers: appClient.makeHeaders(for: userA)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(RecommendedUsers.Response.self)
            XCTAssertGreaterThanOrEqual(body.items.count, 4)
            let uids = body.items.map { $0.id }
            XCTAssertFalse(uids.contains(userA.user.id))
            XCTAssertFalse(uids.contains(userD.user.id))
            XCTAssertTrue(uids.contains(userC.user.id))
        }
        
        _ = try appClient.blockUser(target: userA, with: userC)
        
        try app.test(
            .GET,
            "user_social/recommended_users/\(userA.user.id)?page=1&per=10000000",
            headers: appClient.makeHeaders(for: userA)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(RecommendedUsers.Response.self)
            XCTAssertGreaterThanOrEqual(body.items.count, 4)
            let uids = body.items.map { $0.id }
            XCTAssertFalse(uids.contains(userA.user.id))
            XCTAssertFalse(uids.contains(userD.user.id))
            XCTAssertFalse(uids.contains(userC.user.id))
        }
    }

    func testGetUserFollowers() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser(role: .artist(Artist(part: "bass")))

        try appClient.followUser(target: userA, with: userB)
        try appClient.followUser(target: userA, with: userC)

        try app.test(
            .GET, "user_social/user_followers/\(userA.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(UserFollowers.Response.self)
            XCTAssertEqual(body.items.count, 2)
        }
    }

    func testGetUpcomingLives() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        _ = try appClient.createLive(hostGroup: groupX, with: userA)
        try appClient.follow(group: groupX, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/upcoming_lives?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetUpcomingLives.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }

    func testGetFollowingGroupFeeds() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        _ = try appClient.createArtistFeed(with: userA)
        try appClient.follow(group: groupX, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/group_feeds?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetFollowingGroupFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }

    func testGetFollowingGroupFeedsForDuplicatedArtist() throws {
        let artistA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let groupX = try appClient.createGroup(with: artistA)
        let groupY = try appClient.createGroup(with: artistA)
        _ = try appClient.createArtistFeed(with: artistA)

        let userB = try appClient.createUser()
        try appClient.follow(group: groupX, with: userB)
        try appClient.follow(group: groupY, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/group_feeds?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetFollowingGroupFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 1, String(describing: responseBody.items))
        }
    }
    
    func testGetFollowingUserFeeds() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        _ = try appClient.createUserFeed(with: userA, groupId: groupX.id)
        _ = try appClient.createUserFeed(with: userB, groupId: groupX.id)
        _ = try appClient.createUserFeed(with: userC, groupId: groupX.id)
        try appClient.followUser(target: userA, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/following_user_feeds?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetFollowingUserFeeds.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
        }
    }

    func testLikeLive() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let liveA = try appClient.createLive(hostGroup: groupX, with: userA)
        try appClient.follow(group: groupX, with: userB)

        try appClient.like(live: liveA, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/upcoming_lives?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetUpcomingLives.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
            let item = try XCTUnwrap(responseBody.items.first)
            XCTAssertTrue(item.isLiked)
        }
        try appClient.unlike(live: liveA, with: userB)
        try app.test(.GET, "user_social/upcoming_lives?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetUpcomingLives.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
            let item = try XCTUnwrap(responseBody.items.first)
            XCTAssertFalse(item.isLiked)
        }
    }
    
    func testLikeUserFeed() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let feed = try appClient.createUserFeed(with: userA, groupId: groupX.id)

        try appClient.likeUserFeed(feed: feed, with: userB)
        try appClient.likeUserFeed(feed: feed, with: userC)

        let headerA = appClient.makeHeaders(for: userA)
        let headerB = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/all_user_feeds?page=1&per=10", headers: headerB) { res in
            let responseBody = try res.content.decode(GetAllUserFeeds.Response.self)
            let item = try XCTUnwrap(responseBody.items.filter { $0.id == feed.id }.first)
            XCTAssertTrue(item.isLiked)
            XCTAssertEqual(item.likeCount, 2)
        }
        try app.test(.GET, "user_social/all_user_feeds?page=1&per=10", headers: headerA) { res in
            let responseBody = try res.content.decode(GetAllUserFeeds.Response.self)
            let item = try XCTUnwrap(responseBody.items.filter { $0.id == feed.id }.first)
            XCTAssertFalse(item.isLiked)
        }
    }
    
    func testGetFollowingPosts() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        let post = try appClient.createPost(with: userA)
        _ = try appClient.createPost(with: userB)
        _ = try appClient.createPost(with: userC)
        try appClient.followUser(target: userA, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/following_posts?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetFollowingPosts.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
        }
        
        try app.test(.GET, "user_social/all_posts?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetAllPosts.Response.self)
            XCTAssertGreaterThanOrEqual(responseBody.items.count, 3)
        }
        
        _ = try appClient.likePost(post: post, with: userB)
        
        try app.test(.GET, "user_social/liked_posts/\(userB.user.id)?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetLikedPosts.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }
}
