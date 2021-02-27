import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.UserRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.UserRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        let beforeSignup = routes.grouped(JWTAuthenticator.Payload.guardMiddleware())
        try beforeSignup.on(endpoint: Endpoint.Signup.self, use: injectProvider(createUser))
        try beforeSignup.on(endpoint: Endpoint.SignupStatus.self, use: getSignupStatus)

        let loggedIn = routes.grouped(User.guardMiddleware())
        try loggedIn.on(endpoint: Endpoint.GetUserInfo.self, use: getUser)
        try loggedIn.on(
            endpoint: Endpoint.EditUserInfo.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(EditUserInfo.Request.self)
                return repository.editInfo(userId: user.id, input: input)
            })
        try loggedIn.on(
            endpoint: Endpoint.RegisterDeviceToken.self,
            use: injectProvider(registerDeviceToken))
        
        try loggedIn.on(
            endpoint: Endpoint.CreateUserFeed.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(CreateUserFeed.Request.self)
                let notificationService = makePushNotificationService(request: req)
                let useCase = CreateUserFeedUseCase(
                    userRepository: repository,
                    notificationService: notificationService,
                    eventLoop: req.eventLoop)
                return try useCase((user: user, input: input))
            })
        try loggedIn.on(
            endpoint: PostUserFeedComment.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(PostUserFeedComment.Request.self)
                let notificationService = makePushNotificationService(request: req)
                // FIXME: Move to use case
                return repository.addUserFeedComment(userId: user.id, input: input)
                    .and(repository.getUserFeed(feedId: input.feedId))
                    .flatMap { (comment, feed) in
                        let notification = PushNotification(
                            message: "\(user.name) さんがあなたの投稿にコメントしました")
                        return notificationService.publish(
                            to: feed.author.id, notification: notification
                        )
                        .map { comment }
                    }
            })

        try routes.on(
            endpoint: DeleteUserFeed.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(DeleteUserFeed.Request.self)
                let useCase = DeleteUserFeedUseCase(
                    userRepository: repository, eventLoop: req.eventLoop)
                return try useCase((id: input.id, user: user.id)).map { Empty() }
            })

        try routes.on(
            endpoint: GetUserFeedComments.self,
            use: injectProvider { req, uri, repository in
                return repository.getUserFeedComments(
                    feedId: uri.feedId, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetUserFeeds.self,
            use: injectProvider { req, uri, repository in
                return repository.feeds(userId: uri.userId, page: uri.page, per: uri.per)
            })
    }

    func createUser(req: Request, uri: Signup.URI, repository: Domain.UserRepository) throws
        -> EventLoopFuture<
            Signup.Response
        >
    {
        let jwtPayload = try req.auth.require(JWTAuthenticator.Payload.self)
        let input = try req.content.decode(Signup.Request.self)
        let cognitoId = jwtPayload.sub.value
        let user = repository.create(
            cognitoId: cognitoId, cognitoUsername: jwtPayload.username,
            email: jwtPayload.email, input: input
        )
        return user
    }

    func getUser(req: Request, uri: GetUserInfo.URI) throws -> EventLoopFuture<GetUserInfo.Response>
    {
        let user = try req.auth.require(Domain.User.self)
        return req.eventLoop.makeSucceededFuture(user)
    }

    func getSignupStatus(req: Request, uri: SignupStatus.URI) throws -> EventLoopFuture<
        SignupStatus.Response
    > {
        let isSignedup = req.auth.has(Domain.User.self)
        let response = SignupStatus.Response(isSignedup: isSignedup)
        return req.eventLoop.makeSucceededFuture(response)
    }

    func registerDeviceToken(
        req: Request, uri: RegisterDeviceToken.URI, repository: Domain.UserRepository
    ) throws -> EventLoopFuture<RegisterDeviceToken.Response> {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(RegisterDeviceToken.Request.self)
        let service = makePushNotificationService(request: req)
        return service.register(deviceToken: input.deviceToken, for: user.id)
            .flatMapErrorThrowing {
                guard let error = $0 as? Persistance.UserRepository.Error,
                    case .deviceAlreadyRegistered = error
                else {
                    throw $0
                }
                return
            }
            .map { Empty() }
    }
}

extension Endpoint.User: Content {}

extension Endpoint.SignupStatus.Response: Content {}

extension Endpoint.Empty: Content {}
extension Persistance.UserRepository.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .alreadyCreated: return .badRequest
        case .userNotFound: return .forbidden
        case .deviceAlreadyRegistered: return .ok
        case .cantChangeRole: return .badRequest
        case .feedNotFound: return .forbidden
        case .feedDeleted: return .badRequest
        }
    }
}

extension Endpoint.UserFeed: Content {}

extension Endpoint.UserFeedComment: Content {}
