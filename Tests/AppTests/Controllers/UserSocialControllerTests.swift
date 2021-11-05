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
        let userD = try appClient.createUser()
        let userE = try appClient.createUser()
        let userF = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let groupY = try appClient.createGroup(with: userA)

        try appClient.follow(group: groupX, with: userB)
        try appClient.follow(group: groupY, with: userB)
        
        try appClient.follow(group: groupX, with: userD)
        try appClient.follow(group: groupX, with: userE)
        try appClient.follow(group: groupX, with: userF)
        try appClient.follow(group: groupY, with: userD)
        try appClient.follow(group: groupY, with: userE)
        try appClient.follow(group: groupY, with: userF)

        try app.test(
            .GET, "user_social/following_groups/\(userB.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(FollowingGroups.Response.self)
            XCTAssertEqual(body.items.count, 2)
            let groupFeed = try XCTUnwrap(body.items.first)
            XCTAssertFalse(groupFeed.isFollowing)
            XCTAssertEqual(groupFeed.followersCount, 4)
            XCTAssertGreaterThanOrEqual(groupFeed.watchingCount, 0)
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
        
        try app.test(
            .GET, "user_social/following_groups/\(userB.user.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userB)
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(FollowingGroups.Response.self)
            XCTAssertEqual(body.items.count, 2)
            let groupFeed = try XCTUnwrap(body.items.first)
            XCTAssertTrue(groupFeed.isFollowing)
            XCTAssertEqual(groupFeed.followersCount, 4)
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
        let groupY = try appClient.createGroup(with: userA)
        _ = try appClient.createLive(hostGroup: groupX, with: userA)
        _ = try appClient.createLive(hostGroup: groupY, with: userA)
        try appClient.follow(group: groupX, with: userB)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/upcoming_lives?userId=\(userB.user.id)&page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(GetUpcomingLives.Response.self)
            XCTAssertGreaterThanOrEqual(responseBody.items.count, 1)
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
        let userC = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let liveA = try appClient.createLive(hostGroup: groupX, with: userA)
        try appClient.follow(group: groupX, with: userB)

        try appClient.like(live: liveA, with: userB)
        try appClient.like(live: liveA, with: userC)

        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "lives/\(liveA.id)", headers: headers) { res in
            let live = try res.content.decode(GetLive.Response.self)
            XCTAssertTrue(live.isLiked)
            XCTAssertEqual(live.likeCount, 2)
        }
        
        // create past live
        _ = try appClient.createLive(hostGroup: groupX, with: userA, date: "20000101")
        try app.test(.GET, "lives/\(liveA.id)", headers: headers) { res in
            let live = try res.content.decode(GetLive.Response.self)
            XCTAssertTrue(live.isLiked)
            XCTAssertEqual(live.likeCount, 2)
        }
        
        try app.test(.GET, "user_social/live_liked_users?liveId=\(liveA.id)&page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(GetLiveLikedUsers.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
            let items = try XCTUnwrap(responseBody.items)
            XCTAssertTrue(items.map { $0.id }.contains(userB.user.id))
        }
        
        try appClient.unlike(live: liveA, with: userB)
        try app.test(.GET, "lives/\(liveA.id)", headers: headers) { res in
            let live = try res.content.decode(GetLive.Response.self)
            XCTAssertFalse(live.isLiked)
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
    
    func testGetTrendPosts() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        _ = try appClient.createPost(with: userA)
        _ = try appClient.createPost(with: userB)
        
        let headers = appClient.makeHeaders(for: userB)
        try app.test(.GET, "user_social/trend_posts?page=1&per=10", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(GetTrendPosts.Response.self)
            XCTAssertGreaterThanOrEqual(responseBody.items.count, 2)
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
    
    func testGetLivePost() throws {
        let userA = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        let group = try appClient.createGroup(with: userA)
        let live = try appClient.createLive(hostGroup: group, with: userA)
        
        // create 3 posts
        _ = try appClient.createPost(with: userB, live: live)
        _ = try appClient.createPost(with: userB, live: live)
        _ = try appClient.createPost(with: userC, live: live)
        
        let headers = appClient.makeHeaders(for: userA)
        
        try app.test(.GET, "lives/\(live.id)/posts?page=1&per=100", headers: headers) { res in
            let responseBody = try res.content.decode(GetLivePosts.Response.self)
            XCTAssertGreaterThanOrEqual(responseBody.items.count, 3)
        }
    }
    
    func testGetLikedLiveTransition() throws {
        let user = try appClient.createUser()
        let group = try appClient.createGroup(with: user)
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            return dateFormatter
        }()
        let liveA = try appClient.createLive(hostGroup: group, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: Date()))
        let liveB = try appClient.createLive(hostGroup: group, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: Date()))
        let liveC = try appClient.createLive(hostGroup: group, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: Date()))
        let liveD = try appClient.createLive(hostGroup: group, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: Date()))
        for l in [liveA, liveB, liveC, liveD] { try appClient.like(live: l, with: user) }
        
        try app.test(.GET, "user_social/liked_live_transition?userId=\(user.user.id)", headers: appClient.makeHeaders(for: user)) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(GetLikedLiveTransition.Response.self)
            XCTAssertEqual(responseBody.liveParticipatingCount.count, 1)
            guard let liveParticipatingCount = responseBody.liveParticipatingCount.first else { return }
            XCTAssertEqual(liveParticipatingCount, 4)
        }
    }
    
    func testFrequentlyWatchingGroups() throws {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd"
            return dateFormatter
        }()
        let date = Date()
        let yesterday = date.addingTimeInterval(-60 * 60 * 24)
        
        let user = try appClient.createUser()
        let userB = try appClient.createUser()
        let group = try appClient.createGroup(with: user)
        let groupY = try appClient.createGroup(with: user)
        let liveA = try appClient.createLive(hostGroup: group, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: yesterday))
        let liveB = try appClient.createLive(hostGroup: group, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: yesterday))
        let liveC = try appClient.createLive(hostGroup: group, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: yesterday))
        let liveD = try appClient.createLive(hostGroup: groupY, style: .oneman(performer: group.id), with: user, date: dateFormatter.string(from: yesterday))
        let liveE = try appClient.createLive(hostGroup: groupY, style: .oneman(performer: groupY.id), with: user, date: dateFormatter.string(from: yesterday))
        let liveF = try appClient.createLive(hostGroup: groupY, style: .oneman(performer: groupY.id), with: user, date: dateFormatter.string(from: yesterday))
        for l in [liveA, liveB, liveC, liveD, liveE, liveF] { try appClient.like(live: l, with: userB)}
        
        try app.test(.GET, "user_social/frequently_watching_groups?userId=\(userB.user.id)&per=100&page=1", headers: appClient.makeHeaders(for: user)) { res in
            print(userB.user.id)
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.FrequentlyWatchingGroups.Response.self)
            XCTAssertEqual(responseBody.items.count, 2)
            XCTAssertEqual(responseBody.items[0].watchingCount, 4)
            XCTAssertEqual(responseBody.items[1].watchingCount, 2)
        }
    }
    
    func testGetRecentlyFollowingGroups() throws {
        let user = try appClient.createUser()
        let groupA = try appClient.createGroup(with: user)
        let groupB = try appClient.createGroup(with: user)
        let groupC = try appClient.createGroup(with: user)
        _ = try appClient.updateRecentlyFollowing(groups: [groupA.id, groupB.id, groupC.id], with: user)
        
        try app.test(.GET, "user_social/recently_following_groups/\(user.user.id)", headers: appClient.makeHeaders(for: user)) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode([GroupFeed].self)
            XCTAssertEqual(responseBody.count, 3)
        }
        
        _ = try appClient.updateRecentlyFollowing(groups: [groupA.id, groupB.id], with: user)
        
        try app.test(.GET, "user_social/recently_following_groups/\(user.user.id)", headers: appClient.makeHeaders(for: user)) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode([GroupFeed].self)
            XCTAssertEqual(responseBody.count, 2)
            XCTAssertFalse(responseBody.map { $0.group.id }.contains(groupC.id))
        }
    }
    
    func testUsername() throws {
        let user = try appClient.createUser()
        let headers = appClient.makeHeaders(for: user
        )
        
        // return false
        try app.test(.GET, "user_social/username/hagehage", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let isExists = try res.content.decode(Bool.self)
            XCTAssertFalse(isExists)
        }
        
        let body = RegisterUsername.Request(username: "hagehage")
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        
        try app.test(.POST, "user_social/username", headers: headers, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
        
        try app.test(.GET, "user_social/username/hagehage", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let isExists = try res.content.decode(Bool.self)
            XCTAssertTrue(isExists)
        }
        
        let body2 = RegisterUsername.Request(username: "hagehage\(UUID.init().uuidString)")
        let bodyData2 = try ByteBuffer(data: appClient.encoder.encode(body2))
        
        try app.test(.POST, "user_social/username", headers: headers, body: bodyData2) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }
}
