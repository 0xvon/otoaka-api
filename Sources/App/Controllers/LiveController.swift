import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(_ handler: @escaping (Request, URI, Domain.LiveRepository) throws -> T)
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
        try routes.on(endpoint: Endpoint.GetUpcomingLives.self, use: injectProvider(getUpcomingLives))
    }

    func getLiveInfo(req: Request, uri: GetLive.URI, repository: Domain.LiveRepository) throws -> EventLoopFuture<
        Endpoint.Live
    > {
        guard let liveId = UUID(uuidString: uri.liveId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        return repository.findLive(by: Domain.Live.ID(liveId)).unwrap(or: Abort(.notFound))
            .map { Endpoint.Live(from: $0) }
    }

    func create(req: Request, uri: CreateLive.URI, repository: Domain.LiveRepository) throws -> EventLoopFuture<
        Endpoint.Live
    > {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Endpoint.CreateLive.Request.self)
        guard let hostGroupId = UUID(uuidString: input.hostGroupId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        let performerGroupIds = input.performerGroupIds
            .compactMap(UUID.init(uuidString:))
            .map(Domain.Group.ID.init(rawValue:))
        guard performerGroupIds.count == input.performerGroupIds.count else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        let groupRepository = Persistance.GroupRepository(db: req.db)
        let useCase = CreateLiveUseCase(
            groupRepository: groupRepository,
            liveRepository: repository, eventLoop: req.eventLoop
        )
        return try useCase(
            (
                user: user,
                title: input.title, style: LiveStyle.translate(from: input.style),
                artworkURL: input.artworkURL,
                hostGroupId: Domain.Group.ID(hostGroupId),
                openAt: input.openAt, startAt: input.startAt, endAt: input.endAt,
                performerGroups: performerGroupIds
            )
        )
        .map(Endpoint.Live.init(from:))
    }

    func register(req: Request, uri: RegisterLive.URI, repository: Domain.LiveRepository) throws -> EventLoopFuture<
        Endpoint.Ticket
    > {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Endpoint.RegisterLive.Request.self)
        guard let liveId = UUID(uuidString: input.liveId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        let useCase = JoinLiveUseCase(liveRepository: repository, eventLoop: req.eventLoop)
        return try useCase((liveId: Domain.Live.ID(liveId), user: user)).map {
            Endpoint.Ticket(from: $0)
        }
    }

    func getUpcomingLives(req: Request, uri: GetUpcomingLives.URI, repository: Domain.LiveRepository) throws -> EventLoopFuture<GetUpcomingLives.Response> {
        return repository.get(page: uri.page, per: uri.per).map {
            $0.asEndpointResponse()
        }
    }
}

extension Domain.LiveStyle {
    fileprivate static func translate(from entity: Endpoint.LiveStyle) -> Domain.LiveStyle {
        switch entity {
        case .battle: return .battle
        case .festival: return .festival
        case .oneman: return .oneman
        }
    }

    fileprivate func asEndpointEntity() -> Endpoint.LiveStyle {
        switch self {
        case .battle: return .battle
        case .festival: return .festival
        case .oneman: return .oneman
        }
    }
}

extension Domain.Live: EndpointResponseConvertible {
    func asEndpointResponse() -> Endpoint.Live {
        Endpoint.Live(from: self)
    }
}

extension Endpoint.Live {
    init(from domainEntity: Domain.Live) {
        self.init(
            id: domainEntity.id.rawValue.uuidString,
            title: domainEntity.title,
            style: domainEntity.style.asEndpointEntity(),
            artworkURL: domainEntity.artworkURL,
            author: Endpoint.User(from: domainEntity.author),
            hostGroup: Endpoint.Group(from: domainEntity.hostGroup),
            startAt: domainEntity.startAt, endAt: domainEntity.endAt,
            performers: domainEntity.performers.map(Endpoint.Group.init)
        )
    }
}

extension Endpoint.Live: Content {}

extension Endpoint.Ticket: Content {}

extension Endpoint.Page: Content {}

extension Domain.TicketStatus {
    fileprivate static func translate(from entity: Endpoint.TicketStatus) -> Domain.TicketStatus {
        switch entity {
        case .registered: return .registered
        case .paid: return .paid
        case .joined: return .joined
        }
    }

    fileprivate func asEndpointEntity() -> Endpoint.TicketStatus {
        switch self {
        case .registered: return .registered
        case .paid: return .paid
        case .joined: return .joined
        }
    }
}

extension Endpoint.Ticket {
    init(from domainEntity: Domain.Ticket) {
        self.init(
            id: domainEntity.id.rawValue.uuidString,
            status: domainEntity.status.asEndpointEntity(),
            live: Endpoint.Live(from: domainEntity.live),
            user: Endpoint.User(from: domainEntity.user)
        )
    }
}

extension Domain.Page: EndpointResponseConvertible where T: EndpointResponseConvertible {
    typealias EndpointResponse = Endpoint.Page<T.EndpointResponse>
    func asEndpointResponse() -> EndpointResponse {
        EndpointResponse(
            items: items.map { $0.asEndpointResponse() },
            metadata: Endpoint.PageMetadata(page: metadata.per, per: metadata.per, total: metadata.total)
        )
    }
}
