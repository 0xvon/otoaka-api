import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App
import XCTest

class ExternalControllerTests: XCTestCase {
    var app: Application!
    var appClient: AppClient!
    override func setUp() {
        app = Application(.testing)
        DotEnvFile.load(path: dotEnvPath.path)
        XCTAssertNoThrow(try configure(app))
        appClient = AppClient(application: app, authClient: Auth0Client(app))
    }

    override func tearDown() {
        app.shutdown()
        app = nil
        appClient = nil
    }

    /*
     These E2E tests don't check anything and meaningless but take a long time.
     Controller's logics are very thin and most parts are proven by type-system.
     If you want to test their use-cases, please move tests in Domain module

    func testCheckGlobalIP() throws {
        let user = try appClient.createUser()
        try app.test(
            .GET, "external/global_ip", headers: appClient.makeHeaders(for: user)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testNotifyUpcomingLives() throws {
        let user = try appClient.createUser()
        try app.test(
            .GET, "external/notify_upcoming_lives", headers: appClient.makeHeaders(for: user)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testNotifyPastLives() throws {
        let user = try appClient.createUser()
        try app.test(
            .GET, "external/notify_past_lives", headers: appClient.makeHeaders(for: user)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }

    func testSendNotification() throws {
        let user = try appClient.createUser()
        let body = Endpoint.SendNotification.Request(message: "こんにちは", segment: .all)
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "external/notification", headers: appClient.makeHeaders(for: user),
            body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
    }
    */

    func testGetUserProfile() throws {
        let user = try appClient.createUser()
        let username = "userhoge\(UUID.init().uuidString)"

        let body = RegisterUsername.Request(username: username)
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(
            .POST, "user_social/username", headers: appClient.makeHeaders(for: user), body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }

        try app.test(.GET, "public/user_profile/\(username)") { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(GetUserProfile.Response.self)
            XCTAssertEqual(responseBody.user.id, user.user.id)
        }
    }
    
    func testGetLiveInfo() throws {
        let user = try appClient.createUser()
        let group = try appClient.createGroup(with: user)
        let live = try appClient.createLive(hostGroup: group, with: user)
        
        // 2 users liked
        let user_a = try appClient.createUser()
        let user_b = try appClient.createUser()
        _ = try appClient.like(live: live, with: user_a)
        _ = try appClient.like(live: live, with: user_b)
        
        try app.test(.GET, "public/live_info/\(live.id)") { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(GetLiveInfo.Response.self)
            XCTAssertEqual(responseBody.live.id, live.id)
            XCTAssertEqual(responseBody.likeCount, 2)
        }
    }
    
//    func testEntryGroup() throws {
//        let user = try appClient.createUser()
//
//        let group = try appClient.createGroup(with: user)
//        let body = EntryGroup.Request(groupId: group.id)
//        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
//        let header = appClient.makeHeaders(for: user)
//
//        try app.test(.POST, "external/entry_group", headers: header, body: bodyData) { res in
//            XCTAssertEqual(res.status, .ok, res.body.string)
//        }
//
//        try app.test(.GET, "social_tips/social_tippable_groups", headers: header) { res in
//            XCTAssertEqual(res.status, .ok, res.body.string)
//            let groups = try res.content.decode(GetSocialTippableGroups.Response.self)
//            XCTAssertGreaterThan(groups.count, 0)
//        }
//
//        try app.test(.GET, "groups/\(group.id)", headers: header) { res in
//            XCTAssertEqual(res.status, .ok, res.body.string)
//            let response = try res.content.decode(GetGroup.Response.self)
//            XCTAssertTrue(response.isEntried)
//        }
//    }
    
//    func testFetchLive() throws {
//        let user = try appClient.createUser()
//        let group = try appClient.createGroup(with: user)
//        let body = Endpoint.FetchLive.Request(
//            name: group.name,
//            from: Date(timeInterval: -60*60*24*365, since: Date())
//        )
//        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
//        let header = appClient.makeHeaders(for: user)
//
//        try app.test(.POST, "external/fetch_live", headers: header, body: bodyData) { res in
//            XCTAssertEqual(res.status, .ok, res.body.string)
//        }
//    }
}
