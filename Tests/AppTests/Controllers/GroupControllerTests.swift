@testable import App
import Domain
import Endpoint
import XCTVapor
import StubKit

class GroupControllerTests: XCTestCase {
    var app: Application!
    override func setUp() {
        app = Application(.testing)
        DotEnvFile.load(path: dotEnvPath.path)
        XCTAssertNoThrow(try configure(app))
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCreateBand_Invite_Join() throws {
        // try to create without login
        try app.test(.POST, "groups") { res in
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
            let body = Endpoint.Signup.Request(name: dummyUserName, role: .artist(Artist(part: "vocal")))
            let bodyData = try ByteBuffer(data: JSONEncoder().encode(body))
            
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
            let body = try! Stub.make(InviteGroup.Request.self) {
                let fakeGroup = UUID()
                $0.set(\.groupId, value: fakeGroup.uuidString)
            }
            let bodyData = try ByteBuffer(data: encoder.encode(body))
            // Try to create an invitation for non-existing group
            try app.test(.POST, "groups/invite", headers: headers, body: bodyData) { res in
                XCTAssertNotEqual(res.status, .ok, res.body.string)
            }
        }
        
        do {
            let nonMemberUserName = UUID().uuidString
            let nonMemberUser = try client.createToken(userName: nonMemberUserName).wait()
            defer { try! client.destroyUser(userName: nonMemberUserName).wait() }

            var headers = HTTPHeaders()
            headers.add(name: .authorization, value: "Bearer \(nonMemberUser.token)")
            headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
            
            let body = try! Stub.make(InviteGroup.Request.self) {
                $0.set(\.groupId, value: createdGroup.id)
            }

            let bodyData = try ByteBuffer(data: encoder.encode(body))
            // Try to create an invitation for non-member group
            try app.test(.POST, "groups/invite", headers: headers, body: bodyData) { res in
                XCTAssertNotEqual(res.status, .ok, res.body.string)
            }
        }

        var createdInvitation: Endpoint.InviteGroup.Invitation!
        do {
            let body = try! Stub.make(InviteGroup.Request.self) {
                $0.set(\.groupId, value: createdGroup.id)
            }
            let bodyData = try ByteBuffer(data: encoder.encode(body))
            try app.test(.POST, "groups/invite", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .ok, res.body.string)
                createdInvitation = try res.content.decode(InviteGroup.Response.self)
            }
        }
        
        do {
            let body = try! Stub.make(JoinGroup.Request.self) {
                $0.set(\.invitationId, value: createdInvitation.id)
            }
            let bodyData = try ByteBuffer(data: encoder.encode(body))
            try app.test(.POST, "groups/join", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .ok)
                _ = try res.content.decode(JoinGroup.Response.self)
            }
            
            // Try to join again with the same invitation
            try app.test(.POST, "groups/join", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .badRequest)
            }
        }

        do {
            let body = try! Stub.make(JoinGroup.Request.self) {
                let fakeInvitation = UUID()
                $0.set(\.invitationId, value: fakeInvitation.uuidString)
            }
            let bodyData = try ByteBuffer(data: encoder.encode(body))
            // Try to join with invalid invitation
            try app.test(.POST, "groups/join", headers: headers, body: bodyData) { res in
                XCTAssertEqual(res.status, .badRequest)
            }
        }
    }
}
