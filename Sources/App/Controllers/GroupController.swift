import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T>(_ handler: @escaping (Request, Domain.GroupRepository) throws -> T) -> ((Request) throws -> T) {
    return { req in
        let repository = Persistance.GroupRepository(db: req.db)
        return try handler(req, repository)
    }
}

struct GroupController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.on(endpoint: Endpoint.CreateGroup.self, use: injectProvider(createBand))
        routes.on(endpoint: Endpoint.InviteGroup.self, use: injectProvider(invite))
        routes.on(endpoint: Endpoint.JoinGroup.self, use: injectProvider(join))
    }

    func createBand(req: Request, repository: Domain.GroupRepository) throws -> EventLoopFuture<Endpoint.Group> {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Endpoint.CreateGroup.Request.self)
        return repository.create(
            name: input.name, englishName: input.englishName,
            biography: input.biography, since: input.since,
            artworkURL: input.artworkURL, hometown: input.hometown
        )
        .flatMap { group in
            repository.join(toGroup: group.id, artist: user.id)
                .map { _ in group }
        }
        .map { Endpoint.Group(from: $0) }
    }

    func invite(req: Request, repository: Domain.GroupRepository) throws -> EventLoopFuture<Endpoint.InviteGroup.Response> {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Endpoint.InviteGroup.Request.self)
        guard let groupId = UUID(uuidString: input.groupId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        let userRepository = Persistance.UserRepository(db: req.db)
        let useCase = InviteGroupUseCase(
            groupRepository: repository, userRepository: userRepository,
            eventLopp: req.eventLoop
        )
        let invitation = try useCase((artistId: user.id, groupId: Domain.Group.ID(groupId)))
        return invitation.map { invitation in
            Endpoint.InviteGroup.Invitation(id: invitation.id.rawValue.uuidString)
        }
    }

    func join(req: Request, repository: Domain.GroupRepository) throws -> EventLoopFuture<Empty> {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Endpoint.JoinGroup.Request.self)
        guard let invitationId = UUID(uuidString: input.invitationId) else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        let userRepository = Persistance.UserRepository(db: req.db)
        let useCase = JoinGroupUseCase(groupRepository: repository,
                                       userRepository: userRepository,
                                       eventLopp: req.eventLoop)
        let response = try useCase((invitationId: GroupInvitation.ID(invitationId), user.id))
        return response.map { _ in Empty() }
    }
}

extension Endpoint.Group: Content {
    init(from domainEntity: Domain.Group) {
        self.init(
            id: domainEntity.id.rawValue.uuidString,
            name: domainEntity.name, englishName: domainEntity.englishName,
            biography: domainEntity.biography, since: domainEntity.since,
            artworkURL: domainEntity.artworkURL, hometown: domainEntity.hometown
        )
    }
}

extension Endpoint.InviteGroup.Response: Content {}

extension Domain.JoinGroupUseCase.Error: AbortError {
    public var status: HTTPResponseStatus {
        .badRequest
    }
}
