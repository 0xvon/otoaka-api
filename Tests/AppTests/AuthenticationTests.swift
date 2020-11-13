import Domain
import Endpoint
import XCTVapor

@testable import App

class AuthenticationTests: XCTestCase {
    var app: Application!
    override func setUp() {
        app = Application(.testing)
        DotEnvFile.load(path: dotEnvPath.path)
        XCTAssertNoThrow(try configure(app))
    }

    override func tearDown() {
        app.shutdown()
    }

    func testCognitoPublicKeys() throws {
        XCTAssertNoThrow(try JWTAuthenticator())
    }

    func testVerifyJWT() throws {
        let client = CognitoClient()
        let authenticator = try JWTAuthenticator()
        let dummyUserName = UUID().uuidString
        let dummyEmail = "\(dummyUserName)@example.com"
        let dummyUser = try client.createToken(userName: dummyUserName).wait()
        defer { try! client.destroyUser(userName: dummyUserName).wait() }
        let payload = try authenticator.verifyJWT(token: dummyUser.token)
        XCTAssertEqual(payload.email, dummyEmail)
    }

    class InMemoryUserRepository: Domain.UserRepository {
        var users: [Domain.CognitoID: Domain.User] = [:]
        let eventLoop: EventLoop
        init(eventLoop: EventLoop) {
            self.eventLoop = eventLoop
        }

        func create(
            cognitoId: Domain.CognitoID, email: String, name: String,
            biography: String?, thumbnailURL: String?, role: Endpoint.RoleProperties
        ) -> EventLoopFuture<Endpoint.User> {
            let newUser = Endpoint.User(
                id: .init(UUID()), name: name, biography: biography,
                thumbnailURL: thumbnailURL, role: role
            )
            users[cognitoId] = newUser
            return eventLoop.makeSucceededFuture(newUser)
        }

        func find(by foreignId: Domain.CognitoID) -> EventLoopFuture<Endpoint.User?> {
            eventLoop.makeSucceededFuture(users[foreignId])
        }
        func isExists(by id: Domain.User.ID) -> EventLoopFuture<Bool> {
            eventLoop.makeSucceededFuture(users.contains(where: { $0.value.id == id }))
        }
    }

    func testIntegratedHTTPRequests() throws {
        let client = CognitoClient()
        let dummyUserName = UUID().uuidString
        let dummyEmail = "\(dummyUserName)@example.com"
        let dummyUser = try client.createToken(userName: dummyUserName).wait()
        defer { try! client.destroyUser(userName: dummyUserName).wait() }

        let authenticator = try JWTAuthenticator(userRepositoryFactory: {
            let repo = InMemoryUserRepository(eventLoop: $0.eventLoop)
            _ = try! repo.create(
                cognitoId: dummyUser.sub, email: dummyEmail,
                name: "foo", biography: nil, thumbnailURL: nil, role: .fan(.init())
            ).wait()
            return repo
        })
        app.grouped(authenticator, User.guardMiddleware()).get("secure") { _ in
            "Logged in"
        }

        do {
            // Check for no header
            try app.test(.GET, "secure") { res in
                XCTAssertEqual(res.status, .unauthorized)
            }
        }

        do {
            // Check for invalid token
            var headers = HTTPHeaders()
            headers.add(name: .authorization, value: "Bearer XXXXXXXXXXXXXXX")
            try app.test(.GET, "secure", headers: headers) { res in
                XCTAssertNotEqual(res.status, .ok)
            }
        }

        do {
            // Check authorization works
            var headers = HTTPHeaders()
            headers.add(name: .authorization, value: "Bearer \(dummyUser.token)")
            try app.test(.GET, "secure", headers: headers) { res in
                XCTAssertEqual(res.status, .ok)
            }
        }
    }
}
