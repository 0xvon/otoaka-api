import Domain
import Endpoint
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
        let group = routes.grouped(authenticator)

        let beforeSignup = group.grouped(JWTAuthenticator.Payload.guardMiddleware())
        beforeSignup.on(endpoint: Endpoint.Signup.self, use: injectProvider(createUser))
        beforeSignup.on(endpoint: Endpoint.SignupStatus.self, use: getSignupStatus)

        group.grouped(User.guardMiddleware())
            .on(endpoint: Endpoint.GetUserInfo.self, use: getUser)
    }

    func createUser(req: Request, repository: Domain.UserRepository) throws -> EventLoopFuture<Signup.Response> {
        guard let jwtPayload = req.auth.get(JWTAuthenticator.Payload.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let input = try req.content.decode(Signup.Request.self)
        let cognitoId = jwtPayload.sub.value
        let user = repository.create(
            cognitoId: cognitoId, email: jwtPayload.email,
            name: input.name, biography: input.biography,
            thumbnailURL: input.thumbnailURL, role: input.role.asDomain()
        )
        return user.map { Signup.Response(from: $0) }
    }

    func getUser(req: Request) throws -> EventLoopFuture<GetUserInfo.Response> {
        guard let user = req.auth.get(Domain.User.self) else {
            // unreachable because guard middleware rejects unauthorized requests
            return req.eventLoop.makeFailedFuture(Abort(.unauthorized))
        }
        let response = GetUserInfo.Response(from: user)
        return req.eventLoop.makeSucceededFuture(response)
    }

    func getSignupStatus(req: Request) throws -> EventLoopFuture<SignupStatus.Response> {
        let isSignedup = req.auth.has(Domain.User.self)
        let response = SignupStatus.Response(isSignedup: isSignedup)
        return req.eventLoop.makeSucceededFuture(response)
    }
}

extension Endpoint.Artist {
    init(fromDomain domainArtist: Domain.Artist) {
        self.init(part: domainArtist.part)
    }

    func asDomain() -> Domain.Artist {
        Domain.Artist(part: part)
    }
}

extension Endpoint.RoleProperties {
    init(fromDomain domainUser: Domain.RoleProperties) {
        switch domainUser {
        case let .artist(artist):
            self = .artist(Endpoint.Artist(fromDomain: artist))
        case .fan:
            self = .fan(Fan())
        }
    }

    func asDomain() -> Domain.RoleProperties {
        switch self {
        case let .artist(artist):
            return .artist(artist.asDomain())
        case .fan:
            return .fan
        }
    }
}

extension Endpoint.User: Content {
    init(from domainUser: Domain.User) {
        self.init(
            id: domainUser.id.rawValue.uuidString,
            name: domainUser.name, biography: domainUser.biography,
            thumbnailURL: domainUser.thumbnailURL,
            role: .init(fromDomain: domainUser.role)
        )
    }
}

extension Endpoint.SignupStatus.Response: Content {}

extension Endpoint.Empty: Content {}
extension Persistance.UserRepository.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .alreadyCreated: return .badRequest
        }
    }
}
