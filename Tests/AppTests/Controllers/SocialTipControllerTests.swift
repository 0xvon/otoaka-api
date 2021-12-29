import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App
import XCTest

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
    }
}
