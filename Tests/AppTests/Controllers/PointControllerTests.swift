import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App
import XCTest

class PointControllerTests: XCTestCase {
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
    
    func testUsePoint() throws {
        let user = try appClient.createUser()
        let header = appClient.makeHeaders(for: user)
        let body = Endpoint.AddPoint.Request(point: 2000, expiredAt: nil)
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        
        try app.test(.POST, "points/add", headers: header, body: bodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
        
        let useBody = Endpoint.UsePoint.Request(point: 1000)
        let useBodyData = try ByteBuffer(data: appClient.encoder.encode(useBody))
        
        try app.test(.POST, "points/use", headers: header, body: useBodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
        
        try app.test(.GET, "points/mine", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let point = try res.content.decode(GetMyPoint.Response.self)
            XCTAssertEqual(point, 1000)
        }
        
        try app.test(.GET, "users/\(user.user.id)", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let response = try res.content.decode(GetUserDetail.Response.self)
            XCTAssertEqual(response.user.point, 1000)
        }
        
        try app.test(.POST, "points/use", headers: header, body: useBodyData) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
        
        try app.test(.POST, "points/use", headers: header, body: useBodyData) { res in
            XCTAssertEqual(res.status, .badRequest, res.body.string)
        }
        
        try app.test(.GET, "points/mine", headers: header) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let point = try res.content.decode(GetMyPoint.Response.self)
            XCTAssertEqual(point, 0)
        }
    }
}
