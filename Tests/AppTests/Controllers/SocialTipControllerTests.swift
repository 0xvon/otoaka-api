import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class SocialTipControllerTests: XCTestCase {
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
    
    func testSendSocialTip() throws {
        let user = try appClient.createUser()
        let group = try appClient.createGroup(with: user)
        
        let body = Endpoint.SendSocialTip.Request(
            tip: 2000,
            type: .group(group),
            theme: "このアーティストのオススメなところ",
            message: "hello",
            isRealMoney: true
        )
        let header = appClient.makeHeaders(for: user)
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        try app.test(.POST, "social_tips/send", headers: header, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let tip = try res.content.decode(Endpoint.SocialTip.self)
            XCTAssertEqual(tip.tip, 2000)
        }
        
        try app.test(.GET, "social_tips/all?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetAllTips.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 1)
        }
    }
    
    func testGetTips() throws {
        let userA = try appClient.createUser()
        let userB = try appClient.createUser()
        let groupX = try appClient.createGroup(with: userA)
        let groupY = try appClient.createGroup(with: userA)
        let header = appClient.makeHeaders(for: userA)
        
        // groupXに2人のユーザが投げ銭する
        try appClient.sendSocialTip(with: userA, group: groupX)
        try appClient.sendSocialTip(with: userB, group: groupX)
        
        // groupXのチップは2件になる
        try app.test(.GET, "social_tips/groups/\(groupX.id)?page=1&per=100", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetGroupTips.Response.self)
            XCTAssertEqual(response.items.count, 2)
        }
        
        // groupYのチップは0件
        try app.test(.GET, "social_tips/groups/\(groupY.id)?page=1&per=100", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetGroupTips.Response.self)
            XCTAssertEqual(response.items.count, 0)
        }
        
        // userAがgroupYにチップを送る
        try appClient.sendSocialTip(with: userA, group: groupY)
        
        // userAのチップは2件になる
        try app.test(.GET, "social_tips/users/\(userA.user.id)?page=1&per=100", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetGroupTips.Response.self)
            XCTAssertEqual(response.items.count, 2)
        }
        
        
        // userAがgroupXに追加で投げ銭
        try appClient.sendSocialTip(with: userA, group: groupX)
        
        // 1位はuserAになり、投げ銭額は4000円
        try app.test(.GET, "social_tips/group_ranking/\(groupX.id)?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetGroupTipFromUserRanking.Response.self)
            XCTAssertEqual(response.items.count, 2)
            XCTAssertEqual(response.items[0].tip, 4000)
            XCTAssertEqual(response.items[1].tip, 2000)
        }
        
        // 1位はgroupXになり、投げ銭額は4000円
        try app.test(.GET, "social_tips/user_ranking/\(userA.user.id)?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserTipToGroupRanking.Response.self)
            XCTAssertEqual(response.items.count, 2)
            XCTAssertEqual(response.items[0].tip, 4000)
            XCTAssertEqual(response.items[1].tip, 2000)
        }
        
        try app.test(.GET, "social_tips/user_tip_feed?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserTipFeed.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 1)
        }
        
        try app.test(.GET, "social_tips/entried_groups?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetEntriedGroups.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 1)
        }
        
        try app.test(.GET, "social_tips/daily_group_ranking?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetDailyGroupRanking.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 1)
        }
        
        try app.test(.GET, "social_tips/weekly_group_ranking?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetDailyGroupRanking.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 1)
        }
    }
    
    func testGetHighTips() throws {
        let userA = try appClient.createUser()
        let group = try appClient.createGroup(with: userA)
        let header = appClient.makeHeaders(for: userA)
        
        // 10,000円投げる
        try appClient.sendSocialTip(with: userA, group: group, tip: 10000)
        
        try app.test(.GET, "social_tips/high?page=1&per=10", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetHighTips.Response.self)
            XCTAssertGreaterThanOrEqual(response.items.count, 1)
        }
    }
    
    func testGetSocialTipEvents() throws {
        let userA = try appClient.createUser()
        let group = try appClient.createGroup(with: userA)
        let header = appClient.makeHeaders(for: userA)
        let live = try appClient.createLive(hostGroup: group, with: userA)
        let body = try! Stub.make(CreateSocialTipEvent.Request.self) {
            $0.set(\.liveId, value: live.id)
            $0.set(\.until, value: Date(timeInterval: 60 * 60 * 24 * 30, since: Date()))
            $0.set(\.relatedLink, value: URL(string: "https://www.wall-of-death.com")!)
//            $0.set(\.until, value: Date())
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        
        try app.test(
            .POST, "social_tips/events/create", headers: header, body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok)
        }
        
        try app.test(
            .GET, "social_tips/events?page=1&per=10", headers: header
        ) { res in
            XCTAssertEqual(res.status, .ok)
            let events = try res.content.decode(GetSocialTipEvent.Response.self)
            XCTAssertGreaterThanOrEqual(events.items.count, 1)
            XCTAssertNotNil(events.items.first?.relatedLink)
        }
    }
}
