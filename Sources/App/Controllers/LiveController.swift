import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T>(_ handler: @escaping (Request, Domain.LiveRepository) throws -> T)
    -> ((Request) throws -> T)
{
    return { req in
        let repository = Persistance.LiveRepository(db: req.db)
        return try handler(req, repository)
    }
}

struct LiveController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.on(endpoint: Endpoint.CreateLive.self, use: injectProvider(create))
        routes.on(endpoint: Endpoint.GetLive.self, use: injectProvider(getLiveInfo))
        routes.on(endpoint: Endpoint.RegisterLive.self, use: injectProvider(register))
    }

    func getLiveInfo(req: Request, repository: Domain.LiveRepository) throws -> EventLoopFuture<
        Endpoint.Live
    > {
        let rawLiveId = try req.parameters.require("live_id", as: String.self)
        guard let liveId = UUID(uuidString: rawLiveId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        return repository.findLive(by: Domain.Live.ID(liveId)).unwrap(or: Abort(.notFound))
            .map { Endpoint.Live(from: $0) }
    }

    func create(req: Request, repository: Domain.LiveRepository) throws -> EventLoopFuture<
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

    func register(req: Request, repository: Domain.LiveRepository) throws -> EventLoopFuture<Endpoint.Ticket> {
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
