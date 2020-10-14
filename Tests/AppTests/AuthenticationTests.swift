@testable import App
import Domain
import XCTVapor

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
        let client = CognitoClient(httpClient: app.http.client.shared)
        let authenticator = try JWTAuthenticator()
        let dummyUserName = UUID().uuidString
        let dummyEmail = "\(dummyUserName)@example.com"
        let dummyUser = try client.createToken(userName: dummyUserName).wait()
        defer { try! client.destroyUser(userName: dummyUserName).wait() }
        let payload = try authenticator.verifyJWT(bearer: BearerAuthorization(token: dummyUser.token))
        XCTAssertEqual(payload.email, dummyEmail)
    }

    class InMemoryUserRepository: Domain.UserRepository {
        var users: [User.ForeignID: Domain.User] = [:]
        let eventLoop: EventLoop
        init(eventLoop: EventLoop) {
            self.eventLoop = eventLoop
        }

        func create(foreignId: User.ForeignID) -> EventLoopFuture<User> {
            let newUser = User(id: foreignId)
            users[foreignId] = newUser
            return eventLoop.makeSucceededFuture(newUser)
        }

        func find(by foreignId: User.ForeignID) -> EventLoopFuture<User?> {
            eventLoop.makeSucceededFuture(users[foreignId])
        }
    }

    func testIntegratedHTTPRequests() throws {
        let client = CognitoClient(httpClient: app.http.client.shared)
        let dummyUserName = UUID().uuidString
        let dummyUser = try client.createToken(userName: dummyUserName).wait()
        defer { try! client.destroyUser(userName: dummyUserName).wait() }

        let authenticator = try JWTAuthenticator(userRepositoryFactory: {
            let repo = InMemoryUserRepository(eventLoop: $0.eventLoop)
            _ = try! repo.create(foreignId: User.ForeignID(value: dummyUser.sub)).wait()
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
