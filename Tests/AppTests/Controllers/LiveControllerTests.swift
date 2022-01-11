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
        appClient = AppClient(application: app, authClient: Auth0Client(app))
    }

    override func tearDown() {
        app.shutdown()
        app = nil
        appClient = nil
    }

    func testCreateWithoutLogin() throws {
        try app.test(.POST, "lives") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func testCreateLive() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let createdGroup = try appClient.createGroup(with: user)
        let liveHouse = "livehouse_\(UUID.init().uuidString)"
        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: createdGroup.id)
            $0.set(\.style, value: .oneman(performer: createdGroup.id))
            $0.set(\.liveHouse, value: liveHouse)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        var created: Live!
        try app.test(.POST, "lives", headers: appClient.makeHeaders(for: user), body: bodyData) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.CreateLive.Response.self)
            XCTAssertEqual(responseBody.title, body.title)
            created = responseBody
        }

        let anotherGroup = try appClient.createGroup(with: user)
        let anotherBody = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: anotherGroup.id)
            $0.set(\.style, value: .oneman(performer: anotherGroup.id))
            $0.set(\.liveHouse, value: liveHouse)
        }
        let anotherBodyData = try ByteBuffer(data: appClient.encoder.encode(anotherBody))

        try app.test(
            .POST, "lives", headers: appClient.makeHeaders(for: user), body: anotherBodyData
        ) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.CreateLive.Response.self)
            XCTAssertEqual(responseBody.id, created.id)
        }

        try app.test(.GET, "lives/\(created.id)", headers: appClient.makeHeaders(for: user)) {
            res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetLive.Response.self)
            XCTAssertEqual(
                Set([createdGroup.id, anotherGroup.id]),
                Set(responseBody.live.style.performers.map(\.id)))
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
            $0.set(\.style, value: .oneman(performer: groupX.id))
            $0.set(\.hostGroupId, value: groupX.id)
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

        //        try app.test(
        //            .POST, "lives/edit/\(live.id)", headers: appClient.makeHeaders(for: userB),
        //            body: bodyData
        //        ) {
        //            res in
        //            XCTAssertEqual(res.status, .forbidden, res.body.string)
        //        }
    }

    //    func testCreateLiveAsNonHostMember() throws {
    //        let user = try appClient.createUser(role: .artist(Artist(part: "important")))
    //        let createdGroup = try appClient.createGroup(with: user)
    //
    //        let nonMemberUser = try appClient.createUser()
    //
    //        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
    //            $0.set(\.hostGroupId, value: createdGroup.id)
    //            $0.set(\.style, value: .oneman(performer: createdGroup.id))
    //        }
    //        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
    //        let headers = appClient.makeHeaders(for: nonMemberUser)
    //
    //        try app.test(.POST, "lives", headers: headers, body: bodyData) { res in
    //            XCTAssertNotEqual(res.status, .ok)
    //        }
    //    }

    func testCreateLiveWithDuplicatedPerformers() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let hostGroup = try appClient.createGroup(with: user)

        let artist = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let participatingGroup = try appClient.createGroup(with: artist)

        let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
            $0.set(\.hostGroupId, value: hostGroup.id)
            $0.set(
                \.style, value: .battle(performers: [participatingGroup.id, participatingGroup.id]))
            $0.set(\.liveHouse, value: "livehouse_\(UUID.init().uuidString)")
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

        try app.test(.POST, "lives", headers: headers, body: bodyData) { res in
            XCTAssertNotEqual(res.status, .ok)
        }
    }

    func testGetLive() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let userB = try appClient.createUser()
        _ = try appClient.followUser(target: userB, with: user)
        let headers = appClient.makeHeaders(for: user)
        let hostGroup = try appClient.createGroup(with: user)
        var performers: [Endpoint.Group] = []
        var artists: [AppUser] = []

        // create 3 artists
        for _ in 0..<3 {
            let artist = try appClient.createUser(role: .artist(Artist(part: "vocal")))
            artists.append(artist)
            let group = try appClient.createGroup(with: artist)
            performers.append(group)
        }

        let live = try appClient.createLive(
            hostGroup: hostGroup, style: .battle(performers: performers.map(\.id)), with: user)
        _ = try appClient.like(live: live, with: userB)

        try app.test(.GET, "lives/\(live.id)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let responseBody = try res.content.decode(Endpoint.GetLive.Response.self)
            XCTAssertEqual(
                Set(performers.map(\.id)), Set(responseBody.live.style.performers.map(\.id)))
            XCTAssertEqual(responseBody.participatingFriends.count, 1)
            guard let friend = responseBody.participatingFriends.first else { return }
            XCTAssertEqual(friend.id, userB.user.id)
        }
    }

    func testRegisterLive() throws {
        let user = try appClient.createUser(role: .artist(Artist(part: "vocal")))
        let headers = appClient.makeHeaders(for: user)
        let hostGroup = try appClient.createGroup(with: user)
        let live = try appClient.createLive(
            hostGroup: hostGroup, style: .battle(performers: []), with: user)
        do {
            let body = try! Stub.make(Endpoint.ReserveTicket.Request.self) {
                $0.set(\.liveId, value: live.id)
            }
            let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

            try app.test(.POST, "lives/reserve", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .ok, res.body.string)
            }
            try app.test(.POST, "lives/reserve", headers: headers, body: bodyData) { res in
                XCTAssertNotEqual(res.status, .ok, res.body.string)
            }
        }

        try app.test(
            .GET, "lives/my_tickets?userId=\(user.user.id)&page=1&per=10", headers: headers
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(Endpoint.GetMyTickets.Response.self)
            XCTAssertEqual(response.items.count, 1)
        }

        do {
            let body = try! Stub.make(Endpoint.RefundTicket.Request.self) {
                $0.set(\.liveId, value: live.id)
            }
            let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))

            try app.test(.POST, "lives/refund", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .ok, res.body.string)
            }
        }
    }

    func testGetGroupLives() throws {
        let user = try appClient.createUser(role: .artist(.init(part: "vocal")))
        let groupX = try appClient.createGroup(with: user)
        _ = try appClient.createLive(
            hostGroup: groupX, style: .oneman(performer: groupX.id), with: user)
        let headers = appClient.makeHeaders(for: user)
        try app.test(.GET, "groups/\(groupX.id)/lives?page=1&per=10", headers: headers) { res in
            let responseBody = try res.content.decode(Endpoint.GetGroupLives.Response.self)
            XCTAssertEqual(responseBody.items.count, 1)
        }
    }

    func testSearchLive() throws {
        let user = try appClient.createUser(role: .artist(.init(part: "vocal")))
        let userB = try appClient.createUser()
        let group = try appClient.createGroup(with: user)
        let live = try appClient.createLive(hostGroup: group, with: user)

        let headers = appClient.makeHeaders(for: user)

        try app.test(
            .GET, "lives/search?term=dead+pop&page=1&per=1", headers: headers
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(Endpoint.SearchLive.Response.self)
            XCTAssertGreaterThanOrEqual(body.items.count, 1)
            guard let item = body.items.first else { return }
            XCTAssertEqual(item.live.title, live.title)
        }

        let group2 = try appClient.createGroup(with: user)
        _ = try appClient.createLive(hostGroup: group2, with: user)
        _ = try appClient.createLive(hostGroup: group2, with: user)

        try app.test(
            .GET, "lives/search?groupId=\(group.id)&page=1&per=1", headers: headers
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let body = try res.content.decode(Endpoint.SearchLive.Response.self)
            XCTAssertGreaterThanOrEqual(body.items.count, 1)
            guard let item = body.items.first else { return }
            XCTAssertEqual(item.live.title, live.title)
            switch live.style {
            case .battle(let performers):
                XCTAssertTrue(performers.map { $0.id }.contains(group.id))
                XCTAssertFalse(performers.map { $0.id }.contains(group2.id))
            default: break
            }
        }
    }

    //    func testReplyRequestAccept() throws {
    //        let hostUser = try appClient.createUser(role: .artist(.init(part: "vocal")))
    //        let hostGroup = try appClient.createGroup(with: hostUser)
    //
    //        let userX = try appClient.createUser(role: .artist(.init(part: "foo")))
    //        let groupA = try appClient.createGroup(with: userX)
    //
    //        _ = try appClient.createLive(
    //            hostGroup: hostGroup, style: .battle(performers: [groupA.id, hostGroup.id]),
    //            with: hostUser
    //        )
    //
    //        let requests = try appClient.getPerformanceRequests(with: userX)
    //        XCTAssertEqual(requests.items.count, 1)
    //        let receivedRequest = try XCTUnwrap(requests.items.first)
    //        XCTAssertEqual(receivedRequest.status, .pending)
    //
    //        do {
    //            let requests = try appClient.getPerformanceRequests(with: hostUser)
    //            XCTAssertEqual(requests.items.count, 0)
    //        }
    //
    //        let body = try! Stub.make(ReplyPerformanceRequest.Request.self) {
    //            $0.set(\.reply, value: .accept)
    //            $0.set(\.requestId, value: receivedRequest.id)
    //        }
    //        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
    //
    //        let headers = appClient.makeHeaders(for: userX)
    //        try app.test(.POST, "lives/reply", headers: headers, body: bodyData) { res in
    //            XCTAssertEqual(res.status, .ok, res.body.string)
    //        }
    //
    //        let updatedRequests = try appClient.getPerformanceRequests(with: userX)
    //        XCTAssertEqual(updatedRequests.items.first?.status, .accepted)
    //    }
}
