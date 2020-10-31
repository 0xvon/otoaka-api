import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class LiveControllerTests: XCTestCase {
    var app: Application!
    override func setUp() {
        app = Application(.testing)
        DotEnvFile.load(path: dotEnvPath.path)
        XCTAssertNoThrow(try configure(app))
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCreateLive() throws {
        // try to create without login
        try app.test(.POST, "lives") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
        let client = CognitoClient()
        let dummyCognitoUserName = UUID().uuidString
        let dummyUser = try client.createToken(userName: dummyCognitoUserName).wait()
        defer { try! client.destroyUser(userName: dummyCognitoUserName).wait() }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var headers = HTTPHeaders()
        headers.add(name: .authorization, value: "Bearer \(dummyUser.token)")
        headers.add(name: .contentType, value: HTTPMediaType.json.serialize())

        do {
            let dummyUserName = UUID().uuidString
            let body = Endpoint.Signup.Request(
                name: dummyUserName, role: .artist(Artist(part: "vocal")))
            let bodyData = try ByteBuffer(data: encoder.encode(body))

            try app.test(.POST, "users/signup", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .ok)
                let responseBody = try res.content.decode(Signup.Response.self)
                XCTAssertEqual(responseBody.name, dummyUserName)
            }
        }

        var createdGroup: Endpoint.Group!
        do {
            // Create a group
            let body = try! Stub.make(CreateGroup.Request.self) {
                $0.set(\.name, value: "Super unique lucky name")
            }
            let bodyData = try ByteBuffer(data: encoder.encode(body))
            try app.test(.POST, "groups", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .ok)
                let responseBody = try res.content.decode(CreateGroup.Response.self)
                XCTAssertEqual(responseBody.name, body.name)
                createdGroup = responseBody
            }
        }

        do {
            let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
                $0.set(\.hostGroupId, value: createdGroup.id)
                $0.set(\.performerGroupIds, value: [createdGroup.id])
            }
            let bodyData = try ByteBuffer(data: encoder.encode(body))

            try app.test(.POST, "lives", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .ok)
                let responseBody = try res.content.decode(Endpoint.CreateLive.Response.self)
                XCTAssertEqual(responseBody.title, body.title)
            }
        }
        
        do {
            let nonMemberUserName = UUID().uuidString
            let nonMemberUser = try client.createToken(userName: nonMemberUserName).wait()
            defer { try! client.destroyUser(userName: nonMemberUserName).wait() }

            var headers = HTTPHeaders()
            headers.add(name: .authorization, value: "Bearer \(nonMemberUser.token)")
            headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
            let signUpBody = Endpoint.Signup.Request(
                name: nonMemberUserName, role: .artist(Artist(part: "vocal")))
            let signUpBodyData = try ByteBuffer(data: encoder.encode(signUpBody))

            try app.test(.POST, "users/signup", headers: headers, body: signUpBodyData) { res in
                XCTAssertEqual(res.status, .ok)
            }

            let body = try! Stub.make(Endpoint.CreateLive.Request.self) {
                $0.set(\.hostGroupId, value: createdGroup.id)
                $0.set(\.performerGroupIds, value: [createdGroup.id])
            }
            let bodyData = try ByteBuffer(data: encoder.encode(body))

            try app.test(.POST, "lives", headers: headers, body: bodyData) { res in
                XCTAssertNotEqual(res.status, .ok)
            }
        }
    }
}
