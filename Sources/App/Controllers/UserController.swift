import Domain
import Endpoint
import Foundation
import Persistance
import SNS
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.UserRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.UserRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        let beforeSignup = routes.grouped(JWTAuthenticator.Payload.guardMiddleware())
        try beforeSignup.on(endpoint: Endpoint.Signup.self, use: injectProvider(createUser))
        try beforeSignup.on(endpoint: Endpoint.SignupStatus.self, use: getSignupStatus)

        let loggedIn = routes.grouped(User.guardMiddleware())
        try loggedIn.on(endpoint: Endpoint.GetUserInfo.self, use: getUser)
        try loggedIn.on(
            endpoint: Endpoint.EditUserInfo.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(EditUserInfo.Request.self)
                return repository.editInfo(userId: user.id, input: input)
            })
        try loggedIn.on(
            endpoint: Endpoint.RegisterDeviceToken.self,
            use: injectProvider(registerDeviceToken))
    }

    func createUser(req: Request, uri: Signup.URI, repository: Domain.UserRepository) throws
        -> EventLoopFuture<
            Signup.Response
        >
    {
        let jwtPayload = try req.auth.require(JWTAuthenticator.Payload.self)
        let input = try req.content.decode(Signup.Request.self)
        let cognitoId = jwtPayload.sub.value
        let user = repository.create(
            cognitoId: cognitoId, email: jwtPayload.email, input: input
        )
        return user
    }

    func getUser(req: Request, uri: GetUserInfo.URI) throws -> EventLoopFuture<GetUserInfo.Response>
    {
        let user = try req.auth.require(Domain.User.self)
        return req.eventLoop.makeSucceededFuture(user)
    }

    func getSignupStatus(req: Request, uri: SignupStatus.URI) throws -> EventLoopFuture<
        SignupStatus.Response
    > {
        let isSignedup = req.auth.has(Domain.User.self)
        let response = SignupStatus.Response(isSignedup: isSignedup)
        return req.eventLoop.makeSucceededFuture(response)
    }

    func registerDeviceToken(
        req: Request, uri: RegisterDeviceToken.URI, repository: Domain.UserRepository
    ) throws -> EventLoopFuture<RegisterDeviceToken.Response> {
        let user = try req.auth.require(Domain.User.self)
        let input = try req.content.decode(RegisterDeviceToken.Request.self)
        let service = makePushNotificationService(request: req)
        return service.register(deviceToken: input.deviceToken, for: user.id)
            .map { Empty() }
    }
}

extension Endpoint.User: Content {}

extension Endpoint.SignupStatus.Response: Content {}

extension Endpoint.Empty: Content {}
extension Persistance.UserRepository.Error: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .alreadyCreated: return .badRequest
        case .userNotFound: return .forbidden
        case .deviceAlreadyRegistered: return .ok
        case .cantChangeRole: return .badRequest
        }
    }
}
