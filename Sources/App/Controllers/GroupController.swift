import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.GroupRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.GroupRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct GroupController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(
            endpoint: Endpoint.CreateGroup.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(Endpoint.CreateGroup.Request.self)
                let useCase = CreateGroupUseCase(
                    groupRepository: repository, eventLoop: req.eventLoop)
                return try useCase((input: input, user: user.id))
            })
        try routes.on(endpoint: Endpoint.EditGroup.self, use: injectProvider(edit))
        try routes.on(endpoint: Endpoint.InviteGroup.self, use: injectProvider(invite))
        try routes.on(endpoint: Endpoint.JoinGroup.self, use: injectProvider(join))
        try routes.on(endpoint: Endpoint.GetGroup.self, use: injectProvider(getGroupInfo))

        try routes.on(
            endpoint: Endpoint.GetAllGroups.self,
            use: injectProvider { req, uri, repository in
                return repository.get(page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetMemberships.self,
            use: injectProvider { req, uri, repository in
                repository.getMemberships(for: uri.artistId)
            })
        try routes.on(
            endpoint: Endpoint.CreateArtistFeed.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(CreateArtistFeed.Request.self)
                let notificationService = makePushNotificationService(request: req)
                let useCase = CreateGroupFeedUseCase(
                    groupRepository: repository,
                    notificationService: notificationService,
                    eventLoop: req.eventLoop)
                return try useCase((user: user, input: input))
            })
        try routes.on(
            endpoint: PostFeedComment.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(PostFeedComment.Request.self)
                let notificationService = makePushNotificationService(request: req)
                // FIXME: Move to use case
                return repository.addArtistFeedComment(userId: user.id, input: input)
                    .and(repository.getArtistFeed(feedId: input.feedId))
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
            endpoint: GetFeedComments.self,
            use: injectProvider { req, uri, repository in
                return repository.getArtistFeedComments(
                    feedId: uri.feedId, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetGroupFeed.self,
            use: injectProvider { req, uri, repository in
                return repository.feeds(groupId: uri.groupId, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.SearchGroup.self,
            use: injectProvider { req, uri, repository in
                repository.search(query: uri.term, page: uri.page, per: uri.per)
            })
    }

    func getGroupInfo(req: Request, uri: GetGroup.URI, repository: Domain.GroupRepository) throws
        -> EventLoopFuture<
            Endpoint.GetGroup.Response
        >
    {
        let user = try req.auth.require(User.self)
        let group = repository.findGroup(by: uri.groupId).unwrap(or: Abort(.notFound))
        let isMember = repository.isMember(of: uri.groupId, member: user.id)
        let userSocialRepository = Persistance.UserSocialRepository(db: req.db)
        let isFollowing = userSocialRepository.isFollowing(
            selfUser: user.id, targetGroup: uri.groupId)
        let followersCount = userSocialRepository.followersCount(selfGroup: uri.groupId)
        return group.and(isMember).and(isFollowing).and(followersCount).map {
            ($0.0.0, $0.0.1, $0.1, $1)
        }.map {
            GetGroup.Response(group: $0, isMember: $1, isFollowing: $2, followersCount: $3)
        }
    }

    func invite(req: Request, uri: InviteGroup.URI, repository: Domain.GroupRepository) throws
        -> EventLoopFuture<
            Endpoint.InviteGroup.Response
        >
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.InviteGroup.Request.self)
        let userRepository = Persistance.UserRepository(db: req.db)
        let useCase = InviteGroupUseCase(
            groupRepository: repository, userRepository: userRepository,
            eventLopp: req.eventLoop
        )
        let invitation = try useCase((artistId: user.id, groupId: input.groupId))
        return invitation.map { invitation in
            Endpoint.InviteGroup.Invitation(id: invitation.id.rawValue.uuidString)
        }
    }

    func join(req: Request, uri: JoinGroup.URI, repository: Domain.GroupRepository) throws
        -> EventLoopFuture<Empty>
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.JoinGroup.Request.self)
        guard let invitationId = UUID(uuidString: input.invitationId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        let userRepository = Persistance.UserRepository(db: req.db)
        let useCase = JoinGroupUseCase(
            groupRepository: repository,
            userRepository: userRepository,
            eventLopp: req.eventLoop)
        let response = try useCase((invitationId: GroupInvitation.ID(invitationId), user.id))
        return response.map { _ in Empty() }
    }

    func edit(
        req: Request, uri: EditGroup.URI,
        repository: Domain.GroupRepository
    ) throws
        -> EventLoopFuture<Endpoint.Group>
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.EditGroup.Request.self)
        let precondition = repository.isMember(of: uri.id, member: user.id).flatMapThrowing {
            guard $0 else { throw Abort(.forbidden) }
            return
        }
        return precondition.flatMap { repository.update(id: uri.id, input: input) }
    }
}

extension Endpoint.Group: Content {}

extension Endpoint.InviteGroup.Response: Content {}

extension Endpoint.ArtistFeed: Content {}

extension Endpoint.ArtistFeedComment: Content {}

extension Endpoint.GetGroup.Response: Content {}

extension Domain.JoinGroupUseCase.Error: AbortError {
    public var status: HTTPResponseStatus {
        .badRequest
    }
}
