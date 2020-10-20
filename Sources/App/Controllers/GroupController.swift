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
    }

    func createBand(req: Request, repository: Domain.GroupRepository) throws -> EventLoopFuture<Endpoint.Group> {
        let input = try req.content.decode(Endpoint.CreateGroup.Request.self)
        return repository.create(
            name: input.name, englishName: input.englishName,
            biography: input.biography, since: input.since,
            artworkURL: input.artworkURL, hometown: input.hometown
        )
        .map { Endpoint.Group(from: $0) }
    }
}

extension Endpoint.Group: Content {
    init(from domainEntity: Domain.Group) {
        self.init(
            id: domainEntity.id,
            name: domainEntity.name, englishName: domainEntity.englishName,
            biography: domainEntity.biography, since: domainEntity.since,
            artworkURL: domainEntity.artworkURL, hometown: domainEntity.hometown
        )
    }
}
