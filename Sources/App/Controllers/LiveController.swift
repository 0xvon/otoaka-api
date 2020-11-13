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
        try routes.on(endpoint: Endpoint.GetLive.self, use: injectProvider(getLiveInfo))
        try routes.on(endpoint: Endpoint.RegisterLive.self, use: injectProvider(register))
        try routes.on(
            endpoint: Endpoint.GetUpcomingLives.self, use: injectProvider(getUpcomingLives))
    }

    func getLiveInfo(req: Request, uri: GetLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Live
        >
    {
        guard let liveId = UUID(uuidString: uri.liveId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        return repository.findLive(by: Domain.Live.ID(liveId)).unwrap(or: Abort(.notFound))
    }

    func create(req: Request, uri: CreateLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Live
        >
    {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Endpoint.CreateLive.Request.self)

        let groupRepository = Persistance.GroupRepository(db: req.db)
        let useCase = CreateLiveUseCase(
            groupRepository: groupRepository,
            liveRepository: repository, eventLoop: req.eventLoop
        )
        return try useCase(
            (
                user: user,
                title: input.title, style: input.style,
                artworkURL: input.artworkURL,
                hostGroupId: input.hostGroupId,
                openAt: input.openAt, startAt: input.startAt, endAt: input.endAt,
                performerGroups: input.performerGroupIds
            )
        )
    }

    func register(req: Request, uri: RegisterLive.URI, repository: Domain.LiveRepository) throws
        -> EventLoopFuture<
            Endpoint.Ticket
        >
    {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Endpoint.RegisterLive.Request.self)
        let useCase = JoinLiveUseCase(liveRepository: repository, eventLoop: req.eventLoop)
        return try useCase((liveId: input.liveId, user: user))
    }

    func getUpcomingLives(
        req: Request, uri: GetUpcomingLives.URI, repository: Domain.LiveRepository
    ) throws -> EventLoopFuture<GetUpcomingLives.Response> {
        return repository.get(page: uri.page, per: uri.per)
    }
}

extension Endpoint.Live: Content {}

extension Endpoint.Ticket: Content {}

extension Endpoint.Page: Content {}
