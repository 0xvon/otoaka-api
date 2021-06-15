import Domain
import Endpoint
import StubKit
import XCTVapor

@testable import App

class MessageControllerTests: XCTestCase {
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
    
    func testCreateMessageRoom() throws {
        let userA = try appClient.createUser()
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        
        let body =  Endpoint.CreateMessageRoom.Request(members: [userB.user.id, userC.user.id], name: "room1")
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        
        try app.test(
            .POST, "messages/create_room", headers: appClient.makeHeaders(for: userA), body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let room = try res.content.decode(Endpoint.CreateMessageRoom.Response.self)
            XCTAssertEqual(room.members.count, 2)
            XCTAssertEqual(room.owner.id, userA.user.id)
            XCTAssertEqual(room.latestMessage, nil)
        }
        
        // try to create the same room again: expected to respond bad-request error
        try app.test(
            .POST, "messages/create_room", headers: appClient.makeHeaders(for: userA), body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .badRequest, res.body.string)
        }
    }
    
    func testSendMessage() throws {
        let userA = try appClient.createUser()
        let userB = try appClient.createUser()
        let room = try appClient.createMessageRoom(with: userA, member: [userB])
        
        let body = try! Stub.make(Endpoint.SendMessage.Request.self) {
            $0.set(\.roomId, value: room.id)
        }
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        
        var message: Endpoint.Message!
        try app.test(
            .POST, "messages",
            headers: appClient.makeHeaders(for: userA),
            body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            message = try res.content.decode(Endpoint.Message.self)
            XCTAssertEqual(message.roomId, room.id)
            XCTAssertEqual(message.sentBy.id, userA.user.id)
        }
        
        // try to get room messages: expected to get the latest message
        try app.test(
            .GET,
            "messages/\(room.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userA)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let messages = try res.content.decode(Endpoint.OpenRoomMessages.Response.self)
            XCTAssertEqual(messages.items.count, 1)
            XCTAssertEqual(messages.items.first?.id, message.id)
        }
    }
    
    func testReadMessage() throws {
        let userA = try appClient.createUser()
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        let room = try appClient.createMessageRoom(with: userA, member: [userB, userC])
        _ = try appClient.sendMessage(with: userA, roomId: room.id)
        _ = try appClient.sendMessage(with: userA, roomId: room.id)
        
        try app.test(
            .GET,
            "messages/\(room.id)?page=1&per=10",
            headers: appClient.makeHeaders(for: userB)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let messages = try res.content.decode(Endpoint.OpenRoomMessages.Response.self)
            XCTAssertTrue(messages.items.first!.readingUsers.contains(userA.user))
            XCTAssertTrue(messages.items.first!.readingUsers.contains(userB.user))
            XCTAssertFalse(messages.items.first!.readingUsers.contains(userC.user))
        }
    }
    
    func testDeleteMessageRoom() throws {
        let userA = try appClient.createUser()
        let userB = try appClient.createUser()
        let userC = try appClient.createUser()
        let room = try appClient.createMessageRoom(with: userA, member: [userB, userC])
        _ = try appClient.sendMessage(with: userA, roomId: room.id)
        _ = try appClient.sendMessage(with: userB, roomId: room.id)
        _ = try appClient.sendMessage(with: userC, roomId: room.id)
        
        let body = Endpoint.DeleteMessageRoom.Request(roomId: room.id)
        let bodyData = try ByteBuffer(data: appClient.encoder.encode(body))
        try app.test(
            .DELETE, "messages/delete_room", headers: appClient.makeHeaders(for: userA), body: bodyData
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
        }
        
        try app.test(
            .GET, "messages/rooms?page=\(1)&per=\(100)", headers: appClient.makeHeaders(for: userA)
        ) { res in
            XCTAssertEqual(res.status, .ok, res.body.string)
            let rooms = try res.content.decode(Endpoint.GetRooms.Response.self)
            XCTAssertEqual(rooms.items.count, 0)
        }
    }
}
