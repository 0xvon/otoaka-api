import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.LiveRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.LiveRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct LiveController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(endpoint: Endpoint.CreateLive.self, use: injectProvider(create))
        try routes.on(endpoint: Endpoint.EditLive.self, use: injectProvider(edit))
        try routes.on(
            endpoint: Endpoint.GetLive.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.getLiveDetail(by: uri.liveId, selfUserId: user.id).unwrap(
                    or: Abort(.notFound))
            })
        try routes.on(endpoint: Endpoint.ReserveTicket.self, use: injectProvider(reserveTicket))
        try routes.on(
            endpoint: Endpoint.RefundTicket.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(Endpoint.RefundTicket.Request.self)
                return repository.refundTicket(liveId: input.liveId, user: user.id).map { Empty() }
            })
        try routes.on(
            endpoint: Endpoint.ReplyPerformanceRequest.self, use: injectProvider(replyRequest))
        try routes.on(
            endpoint: Endpoint.GetPerformanceRequests.self,
            use: injectProvider(getPerformanceRequests))
        try routes.on(
            endpoint: Endpoint.GetPendingRequestCount.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.getPendingRequestCount(for: user.id)
                    .map { GetPendingRequestCount.Response(pendingRequestCount: $0) }
            })
        try routes.on(
            endpoint: Endpoint.GetGroupLives.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.get(selfUser: user.id, page: uri.page, per: uri.per, group: uri.groupId)
            })
        try routes.on(
            endpoint: Endpoint.SearchLive.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.search(selfUser: user.id, query: uri.term, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetMyTickets.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.getUserTickets(userId: uri.userId, selfUser: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetLiveParticipants.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let groupRepository = makeGroupRepository(request: req)
                let live = repository.getLive(by: uri.liveId)
                let precondition = live.unwrap(orError: Abort(.notFound))
                    .flatMap {
                        groupRepository.isMember(of: $0.hostGroup.id, member: user.id).and(
                            value: $0)
                    }
                    .guard({ $0.0 }, else: Abort(.badRequest))
                return precondition.flatMap { _, live in
                    repository.getParticipants(liveId: live.id, page: uri.page, per: uri.per)
                }
            })
    }

    func create(req: Request, uri: CreateLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Live
        >
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.CreateLive.Request.self)

        let groupRepository = makeGroupRepository(request: req)
        let notificationService = makePushNotificationService(request: req)
        let useCase = CreateLiveUseCase(
            groupRepository: groupRepository,
            liveRepository: repository,
            notificationService: notificationService,
            eventLoop: req.eventLoop
        )
        return try useCase((user: user, input: input))
    }

    func edit(req: Request, uri: EditLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Live
        >
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.EditLive.Request.self)

        let groupRepository = Persistance.GroupRepository(db: req.db)
        let useCase = EditLiveUseCase(
            groupRepository: groupRepository,
            liveRepository: repository, eventLoop: req.eventLoop
        )
        return try useCase((id: uri.id, user: user, input: input))
    }

    func reserveTicket(req: Request, uri: ReserveTicket.URI, repository: Domain.LiveRepository)
        throws
        -> EventLoopFuture<
            ReserveTicket.Response
        >
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.ReserveTicket.Request.self)
        let useCase = ReserveLiveTicketUseCase(liveRepository: repository, eventLoop: req.eventLoop)
        return try useCase((liveId: input.liveId, user: user))
            .map { Empty() }
    }

    func replyRequest(
        req: Request, uri: ReplyPerformanceRequest.URI, repository: Domain.LiveRepository
    ) throws -> EventLoopFuture<
        ReplyPerformanceRequest.Response
    > {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.ReplyPerformanceRequest.Request.self)
        let groupRepository = Persistance.GroupRepository(db: req.db)
        let useCase = ReplyPerformanceRequestUseCase(
            groupRepository: groupRepository, liveRepository: repository, eventLoop: req.eventLoop)
        return try useCase((user: user, input: input)).map { Empty() }
    }

    func getPerformanceRequests(
        req: Request, uri: GetPerformanceRequests.URI, repository: Domain.LiveRepository
    ) throws -> EventLoopFuture<GetPerformanceRequests.Response> {
        let user = try req.auth.require(Domain.User.self)
        return repository.getRequests(for: user.id, page: uri.page, per: uri.per)
    }
}

extension Endpoint.Live: Content {}

extension Endpoint.Ticket: Content {}

extension Endpoint.Page: Content {}

extension Endpoint.GetLive.Response: Content {}

extension Endpoint.GetPendingRequestCount.Response: Content {}

extension EditLiveUseCase.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .fanCannotEditLive: return .forbidden
        case .liveNotFound: return .notFound
        case .isNotMemberOfHostGroup: return .forbidden
        }
    }
}
