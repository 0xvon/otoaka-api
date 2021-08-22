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
        func editPost(for input: CreatePost.Request, postId: Post.ID) -> EventLoopFuture<Post> {
            fatalError("unimplemented")
        }
        
        func addPostComment(userId: User.ID, input: AddPostComment.Request) -> EventLoopFuture<PostComment> {
            fatalError("unimplemented")
        }
        
        func getPostComments(postId: Post.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostComment>> {
            fatalError("unimplemented")
        }
        
        func createPost(for input: CreatePost.Request, authorId: User.ID) -> EventLoopFuture<Post> {
            fatalError("unimplemented")
        }
        
        func deletePost(postId: Post.ID) -> EventLoopFuture<Void> {
            fatalError("unimplemented")
        }
        
        func getPost(postId: Post.ID) -> EventLoopFuture<Post> {
            fatalError("unimplemented")
        }
        
        func findPostSummary(postId: Post.ID, userId: User.ID) -> EventLoopFuture<PostSummary> {
            fatalError("unimplemented")
        }
        
        func posts(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostSummary>> {
            fatalError("unimplemented")
        }
        
        func findUserFeedSummary(userFeedId: UserFeed.ID, userId: User.ID) -> EventLoopFuture<UserFeedSummary?> {
            fatalError("unimplemented")
        }
        
        func getNotifications(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserNotification>> {
            fatalError("unimplemented")
        }
        
        func readNotification(notificationId: UserNotification.ID) -> EventLoopFuture<Void> {
            fatalError("unimplemented")
        }
        
        func find(by userId: User.ID) -> EventLoopFuture<User?> {
            fatalError("unimplemented")
        }
        
        func search(query: String, page: Int, per: Int) -> EventLoopFuture<Page<User>> {
            fatalError("unimplemented")
        }
        
        func createFeed(for input: CreateUserFeed.Request, authorId: User.ID) -> EventLoopFuture<UserFeed> {
            fatalError("unimplemented")
        }
        
        func deleteFeed(id: UserFeed.ID) -> EventLoopFuture<Void> {
            fatalError("unimplemented")
        }
        
        func getUserFeed(feedId: UserFeed.ID) -> EventLoopFuture<UserFeed> {
            fatalError("unimplemented")
        }
        
        func addUserFeedComment(userId: User.ID, input: PostUserFeedComment.Request) -> EventLoopFuture<UserFeedComment> {
            fatalError("unimplemented")
        }
        
        func getUserFeedComments(feedId: UserFeed.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserFeedComment>> {
            fatalError("unimplemented")
        }
        
        func feeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserFeedSummary>> {
            fatalError("unimplemented")
        }
        

        func editInfo(userId: User.ID, input: EditUserInfo.Request) -> EventLoopFuture<User> {
            fatalError("unimplemented")
        }

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

        func create(cognitoId: CognitoID, cognitoUsername: CognitoUsername, email: String, input: Signup.Request) -> EventLoopFuture<
            Endpoint.User
        > {
            let newUser = Endpoint.User(
                id: .init(UUID()),
                name: input.name,
                biography: input.biography,
                sex: try! Stub.make(),
                age: try! Stub.make(),
                liveStyle: try! Stub.make(),
                residence: try! Stub.make(),
                thumbnailURL: input.thumbnailURL,
                role: input.role,
                twitterUrl: try! Stub.make(),
                instagramUrl: try! Stub.make()
            )
            users[cognitoUsername.lowercased()] = newUser
            return eventLoop.makeSucceededFuture(newUser)
        }

        func find(by foreignId: Domain.CognitoID) -> EventLoopFuture<Endpoint.User?> {
            eventLoop.makeSucceededFuture(users[foreignId])
        }
        func findByUsername(username: CognitoUsername) -> EventLoopFuture<User?> {
            eventLoop.makeSucceededFuture(users[username.lowercased()])
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
                cognitoId: dummyUser.sub, cognitoUsername: dummyUserName,
                email: dummyEmail, input: Stub.make()
            )
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
