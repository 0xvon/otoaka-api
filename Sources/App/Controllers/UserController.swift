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

        let beforeSignup = routes.grouped(
            JWTAuthenticator.Payload.guardMiddleware(
                throwing: Abort(
                    .unauthorized, reason: "\(JWTAuthenticator.Payload.self) not authenticated.",
                    stackTrace: nil)
            ))
        try beforeSignup.on(endpoint: Endpoint.Signup.self, use: injectProvider(createUser))
        try beforeSignup.on(endpoint: Endpoint.SignupStatus.self, use: getSignupStatus)

        let loggedIn = routes.grouped(
            User.guardMiddleware(
                throwing: Abort(
                    .unauthorized, reason: "\(User.self) not authenticated.", stackTrace: nil)
            ))
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
            endpoint: Endpoint.GetUserDetail.self,
            use: injectProvider(getUserDetail))
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
            endpoint: GetUserFeed.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                return repository.findUserFeedSummary(userFeedId: uri.feedId, userId: user.id)
                    .unwrap(or: Abort(.notFound))
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
        try loggedIn.on(
            endpoint: Endpoint.CreatePost.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(CreatePost.Request.self)
                let notificationService = makePushNotificationService(request: req)
                let useCase = CreatePostUserCase(
                    userRepository: repository, notificationService: notificationService,
                    eventLoop: req.eventLoop)
                return try useCase((user: user, input: input))
            })
        try loggedIn.on(
            endpoint: Endpoint.EditPost.self,
            use: injectProvider { req, uri, repository in
                let input = try req.content.decode(EditPost.Request.self)
                return repository.editPost(for: input, postId: uri.id)
            })
        try routes.on(
            endpoint: Endpoint.DeletePost.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(DeletePost.Request.self)
                let useCase = DeletePostUseCase(
                    userRepository: repository, eventLoop: req.eventLoop)
                return try useCase((postId: input.postId, userId: user.id)).map { Empty() }
            })
        try routes.on(
            endpoint: Endpoint.GetPosts.self,
            use: injectProvider { req, uri, repository in
                return repository.posts(userId: uri.userId, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetPost.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                return repository.findPostSummary(postId: uri.postId, userId: user.id)
            })
        try loggedIn.on(
            endpoint: AddPostComment.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(AddPostComment.Request.self)
                let notificationService = makePushNotificationService(request: req)
                let useCase = AddPostCommentUseCase(
                    userRepository: repository, notificationService: notificationService,
                    eventLoop: req.eventLoop)
                return try useCase((user: user, input: input))
            })
        try routes.on(
            endpoint: GetPostComments.self,
            use: injectProvider { req, uri, repository in
                return repository.getPostComments(postId: uri.postId, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.SearchUser.self,
            use: injectProvider { req, uri, repository in
                repository.search(query: uri.term, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetNotifications.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                return repository.getNotifications(userId: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.ReadNotification.self,
            use: injectProvider { req, uri, repository in
                let input = try req.content.decode(ReadNotification.Request.self)
                return repository.readNotification(notificationId: input.notificationId).map {
                    Empty()
                }
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

    func getUserDetail(req: Request, uri: GetUserDetail.URI, repository: Domain.UserRepository)
        throws
        -> EventLoopFuture<
            Endpoint.GetUserDetail.Response
        >
    {
        let selfUser = try req.auth.require(User.self)
        let user = repository.find(by: uri.userId).unwrap(or: Abort(.notFound))

        let userSocialRepository = Persistance.UserSocialRepository(db: req.db)

        let followersCount = userSocialRepository.userFollowersCount(selfUser: uri.userId)
        let followingUsersCount = userSocialRepository.followingUsersCount(selfUser: uri.userId)
        let postCount = userSocialRepository.userPostCount(selfUser: uri.userId)
        let likePostCount = userSocialRepository.userLikePostCount(selfUser: uri.userId)
        let followingGroupsCount = userSocialRepository.followingGroupsCount(userId: uri.userId)
        let likeFutureLiveCount = userSocialRepository.userLikeLiveCount(
            selfUser: uri.userId, type: .future)
        let likePastLiveCount = userSocialRepository.userLikeLiveCount(
            selfUser: uri.userId, type: .past)
        let isFollowed = userSocialRepository.isUserFollowing(
            selfUser: uri.userId, targetUser: selfUser.id)
        let isFollowing = userSocialRepository.isUserFollowing(
            selfUser: selfUser.id, targetUser: uri.userId)
        let isBlocked = userSocialRepository.isBlocking(selfUser: uri.userId, target: selfUser.id)
        let isBlocking = userSocialRepository.isBlocking(selfUser: selfUser.id, target: uri.userId)

        return user.and(followersCount)
            .and(followingUsersCount)
            .and(postCount)
            .and(likePostCount)
            .and(likeFutureLiveCount)
            .and(likePastLiveCount)
            .and(followingGroupsCount)
            .and(isFollowed)
            .and(isFollowing)
            .and(isBlocked)
            .and(isBlocking)
            .map {
                (
                    $0.0.0.0.0.0.0.0.0.0.0,
                    $0.0.0.0.0.0.0.0.0.0.1,
                    $0.0.0.0.0.0.0.0.0.1,
                    $0.0.0.0.0.0.0.0.1,
                    $0.0.0.0.0.0.0.1,
                    $0.0.0.0.0.0.1,
                    $0.0.0.0.0.1,
                    $0.0.0.0.1,
                    $0.0.0.1,
                    $0.0.1,
                    $0.1,
                    $1
                )
            }.map {
                GetUserDetail.Response(
                    user: $0,
                    followersCount: $1,
                    followingUsersCount: $2,
                    postCount: $3,
                    likePostCount: $4,
                    likeFutureLiveCount: $5,
                    likePastLiveCount: $6,
                    followingGroupsCount: $7,
                    isFollowed: $8,
                    isFollowing: $9,
                    isBlocked: $10,
                    isBlocking: $11
                )
            }
    }
}

extension Endpoint.User: Content {}
extension Endpoint.SignupStatus.Response: Content {}
extension Endpoint.UserDetail: Content {}

extension Endpoint.Empty: Content {}
extension Persistance.UserRepository.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .alreadyCreated: return .badRequest
        case .userNotFound: return .forbidden
        case .userNotificationNotFound: return .forbidden
        case .userNotificationAlreadyRead: return .badRequest
        case .deviceAlreadyRegistered: return .ok
        case .cantChangeRole: return .badRequest
        case .feedNotFound: return .forbidden
        case .feedDeleted: return .badRequest
        case .postNotFound: return .forbidden
        case .postDeleted: return .badRequest
        }
    }
}

extension Endpoint.UserFeed: Content {}
extension Endpoint.UserFeedSummary: Content {}
extension Endpoint.UserFeedComment: Content {}

extension Endpoint.Post: Content {}
extension Endpoint.PostSummary: Content {}
extension Endpoint.PostComment: Content {}
