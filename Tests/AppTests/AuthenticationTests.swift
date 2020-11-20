import Domain
import Endpoint
import Persistance
import StubKit
import XCTVapor

@testable import App

extension JWTAuthenticator {
    convenience init(
        userRepositoryFactory: @escaping (Request) -> Domain.UserRepository = {
            Persistance.UserRepository(db: $0.db)
        }
    ) throws {
        let secrets = EnvironmentSecrets()
        try self.init(
            awsRegion: secrets.awsRegion,
            cognitoUserPoolId: secrets.cognitoUserPoolId,
            userRepositoryFactory: userRepositoryFactory
        )
    }
}

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
        func endpointArns(for id: User.ID) -> EventLoopFuture<[String]> {
            fatalError("unimplemented")
        }

        func setEndpointArn(_ endpointArn: String, for id: User.ID) -> EventLoopFuture<Void> {
            fatalError("unimplemented")
        }

        var users: [Domain.CognitoID: Domain.User] = [:]
        let eventLoop: EventLoop
        init(eventLoop: EventLoop) {
            self.eventLoop = eventLoop
        }

        func create(cognitoId: CognitoID, email: String, input: Signup.Request) -> EventLoopFuture<
            Endpoint.User
        > {
            let newUser = Endpoint.User(
                id: .init(UUID()), name: input.name, biography: input.biography,
                thumbnailURL: input.thumbnailURL, role: input.role
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
            _ = try! repo.create(cognitoId: dummyUser.sub, email: dummyEmail, input: Stub.make())
                .wait()
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
