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
                return repository.findLive(by: uri.liveId, selfUerId: user.id).unwrap(
                    or: Abort(.notFound))
            })
        try routes.on(endpoint: Endpoint.ReserveTicket.self, use: injectProvider(reserveTicket))
        try routes.on(
            endpoint: Endpoint.RefundTicket.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(Endpoint.RefundTicket.Request.self)
                return repository.refundTicket(ticketId: input.ticketId, user: user.id)
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
                repository.get(page: uri.page, per: uri.per, group: uri.groupId)
            })
        try routes.on(
            endpoint: Endpoint.SearchLive.self,
            use: injectProvider { req, uri, repository in
                repository.search(query: uri.term, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetMyTickets.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.getUserTickets(userId: user.id, page: uri.page, per: uri.per)
            })
    }

    func create(req: Request, uri: CreateLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Live
        >
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.CreateLive.Request.self)

        let groupRepository = Persistance.GroupRepository(db: req.db)
        let userSocialRepository = Persistance.UserSocialRepository(db: req.db)
        let userRepository = Persistance.UserRepository(db: req.db)
        let notificationService = SimpleNotificationService(
            secrets: req.application.secrets,
            userRepository: userRepository,
            eventLoop: req.eventLoop
        )
        let useCase = CreateLiveUseCase(
            groupRepository: groupRepository,
            liveRepository: repository,
            userSocialRepository: userSocialRepository,
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
            Endpoint.Ticket
        >
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.ReserveTicket.Request.self)
        let useCase = ReserveLiveTicketUseCase(liveRepository: repository, eventLoop: req.eventLoop)
        return try useCase((liveId: input.liveId, user: user))
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
