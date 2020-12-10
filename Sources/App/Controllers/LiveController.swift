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
        try routes.on(endpoint: Endpoint.GetLive.self, use: injectProvider(getLiveInfo))
        try routes.on(endpoint: Endpoint.ReserveTicket.self, use: injectProvider(reserveTicket))
        try routes.on(
            endpoint: Endpoint.ReplyPerformanceRequest.self, use: injectProvider(replyRequest))
        try routes.on(
            endpoint: Endpoint.GetPerformanceRequests.self,
            use: injectProvider(getPerformanceRequests))
        try routes.on(
            endpoint: Endpoint.GetGroupLives.self,
            use: injectProvider { req, uri, repository in
                repository.get(page: uri.page, per: uri.per, group: uri.groupId)
            })
    }

    func getLiveInfo(req: Request, uri: GetLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Live
        >
    {
        return repository.findLive(by: uri.liveId).unwrap(or: Abort(.notFound))
    }

    func create(req: Request, uri: CreateLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Live
        >
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.CreateLive.Request.self)

        let groupRepository = Persistance.GroupRepository(db: req.db)
        let useCase = CreateLiveUseCase(
            groupRepository: groupRepository,
            liveRepository: repository, eventLoop: req.eventLoop
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

extension EditLiveUseCase.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .fanCannotEditLive: return .forbidden
        case .liveNotFound: return .notFound
        case .isNotMemberOfHostGroup: return .forbidden
        }
    }
}
