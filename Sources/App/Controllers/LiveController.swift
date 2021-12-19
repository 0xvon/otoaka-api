import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.LiveRepository) async throws -> T
)
    -> ((Request, URI) async throws -> T)
{
    return { req, uri in
        let repository = Persistance.LiveRepository(db: req.db)
        return try await handler(req, uri, repository)
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
                let liveDetail = try await repository.getLiveDetail(by: uri.liveId, selfUserId: user.id)
                return liveDetail
            })
        try routes.on(endpoint: Endpoint.ReserveTicket.self, use: injectProvider(reserveTicket))
        try routes.on(
            endpoint: Endpoint.RefundTicket.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(Endpoint.RefundTicket.Request.self)
                try await repository.refundTicket(liveId: input.liveId, user: user.id)
                return Empty()
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
                let pendingCount = try await repository.getPendingRequestCount(for: user.id)
                return GetPendingRequestCount.Response(pendingRequestCount: pendingCount)
            })
        try routes.on(
            endpoint: Endpoint.GetGroupLives.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return try await repository.get(selfUser: user.id, page: uri.page, per: uri.per, group: uri.groupId)
            })
        try routes.on(
            endpoint: Endpoint.SearchLive.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return try await repository.search(selfUser: user.id, query: uri.term, groupId: uri.groupId, fromDate: uri.fromDate, toDate: uri.toDate, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetMyTickets.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return try await repository.getUserTickets(userId: uri.userId, selfUser: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: Endpoint.GetLiveParticipants.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let groupRepository = makeGroupRepository(request: req)
                guard let live = try await repository.getLive(by: uri.liveId).get() else { throw Abort(.notFound, stackTrace: nil) }
                guard try await groupRepository.isMember(of: live.hostGroup.id, member: user.id).get() else { throw Abort(.badRequest, stackTrace: nil) }
                
                return try await repository.getParticipants(liveId: live.id, page: uri.page, per: uri.per).get()
            })
        try routes.on(endpoint: GetLivePosts.self, use: injectProvider { req, uri, repository in
            let user = try req.auth.require(Domain.User.self)
            return try await repository.getLivePosts(liveId: uri.liveId, userId: user.id, page: uri.page, per: uri.per).get()
        })
    }

    func create(req: Request, uri: CreateLive.URI, repository: Domain.LiveRepository) async throws
        -> Endpoint.Live
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
        return try await useCase((user: user, input: input))
    }

    func edit(req: Request, uri: EditLive.URI, repository: Domain.LiveRepository) async throws
        -> Endpoint.Live
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.EditLive.Request.self)

        let groupRepository = Persistance.GroupRepository(db: req.db)
        let useCase = EditLiveUseCase(
            groupRepository: groupRepository,
            liveRepository: repository, eventLoop: req.eventLoop
        )
        return try await useCase((id: uri.id, user: user, input: input))
    }

    func reserveTicket(req: Request, uri: ReserveTicket.URI, repository: Domain.LiveRepository)
        async throws
        -> ReserveTicket.Response
    {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.ReserveTicket.Request.self)
        let useCase = ReserveLiveTicketUseCase(liveRepository: repository, eventLoop: req.eventLoop)
        try await useCase((liveId: input.liveId, user: user))
        return Empty()
    }

    func replyRequest(
        req: Request, uri: ReplyPerformanceRequest.URI, repository: Domain.LiveRepository
    ) async throws -> ReplyPerformanceRequest.Response {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(Endpoint.ReplyPerformanceRequest.Request.self)
        let groupRepository = Persistance.GroupRepository(db: req.db)
        let useCase = ReplyPerformanceRequestUseCase(
            groupRepository: groupRepository, liveRepository: repository, eventLoop: req.eventLoop)
        try await useCase((user: user, input: input)).get()
        return Empty()
    }

    func getPerformanceRequests(
        req: Request, uri: GetPerformanceRequests.URI, repository: Domain.LiveRepository
    ) async throws -> GetPerformanceRequests.Response {
        let user = try req.auth.require(Domain.User.self)
        return try await repository.getRequests(for: user.id, page: uri.page, per: uri.per)
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
//        case .fanCannotEditLive: return .forbidden
        case .liveNotFound: return .notFound
//        case .isNotMemberOfHostGroup: return .forbidden
        }
    }
}
