import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

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
    
//    func testEntryGroup() throws {
//        let user = try appClient.createUser()
//
//        let group = try appClient.createGroup(with: user)
//        let body = EntryGroup.Request(groupId: group.id)
//        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
//
//        try app.test(.POST, "external/entry_group", headers: appClient.makeHeaders(for: user), body: bodyData) { res in
//            XCTAssertEqual(res.status, .ok, res.body.string)
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
