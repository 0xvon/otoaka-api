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
        let users = routes.grouped("users")
        users.post(use: injectProvider(createUser))
        try users.grouped(JWTAuthenticator()).get("get", use: getUser)
    }

    func createUser(req: Request, repository: Domain.UserRepository) throws -> EventLoopFuture<Domain.User> {
        struct Input: Content {
            let id: Domain.User.ForeignID
        }
        let input = try req.content.decode(Input.self)
        return repository.create(foreignId: input.id)
    }

    func getUser(req: Request) throws -> EventLoopFuture<Domain.User> {
        guard let user = req.auth.get(Domain.User.self) else {
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        return req.eventLoop.makeSucceededFuture(user)
    }
}

extension Domain.User: Content {}
