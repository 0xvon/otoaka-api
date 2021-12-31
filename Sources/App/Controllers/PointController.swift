import Domain
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.PointRepository) async throws -> T
)
    -> ((Request, URI) async throws -> T)
{
    return { req, uri in
        let repository = Persistance.PointRepository(db: req.db)
        return try await handler(req, uri, repository)
    }
}

struct PointController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(endpoint: Endpoint.AddPoint.self, use: injectProvider { req, uri, repository in
            let user = try req.auth.require(User.self)
            let request = try req.content.decode(AddPoint.Request.self)
            return try await repository.add(userId: user.id, input: request)
        })
        try routes.on(endpoint: Endpoint.UsePoint.self, use: injectProvider { req, uri, repository in
            let user = try req.auth.require(User.self)
            let request = try req.content.decode(UsePoint.Request.self)
            return try await repository.use(userId: user.id, input: request)
        })
        try routes.on(endpoint: Endpoint.GetMyPoint.self, use: injectProvider { req, uri, repository in
            let user = try req.auth.require(User.self)
            return try await repository.get(userId: user.id)
        })
    }
}

extension Endpoint.Point: Content {}

extension Persistance.PointRepository.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .noEnoughPoints:
            return .badRequest
        }
    }
}
