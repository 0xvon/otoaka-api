import Domain
import Foundation
import Persistance
import Vapor

private func injectProvider<T>(_ handler: @escaping (Request, Domain.UserRepository) throws -> T) -> ((Request) throws -> T) {
    return { req in
        let repository = Persistance.UserRepository(db: req.db)
        return try handler(req, repository)
    }
}

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let authenticator = try JWTAuthenticator()
        let users = routes.grouped("users").grouped(authenticator)

        users.grouped(JWTAuthenticator.Payload.guardMiddleware())
            .post("create", use: injectProvider(createUser))
        users.grouped(User.guardMiddleware())
            .get("get_info", use: getUser)
    }

    func createUser(req: Request, repository: Domain.UserRepository) throws -> EventLoopFuture<Domain.User> {
        guard let jwtPayload = req.auth.get(JWTAuthenticator.Payload.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let foreignId = User.ForeignID(value: jwtPayload.sub.value)
        return repository.create(foreignId: foreignId)
    }

    func getUser(req: Request) throws -> EventLoopFuture<Domain.User> {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        return req.eventLoop.makeSucceededFuture(user)
    }
}

extension Domain.User: Content {}
extension Persistance.UserRepository.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .alreadyCreated: return .badRequest
        }
    }
}
