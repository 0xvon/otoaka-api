import Vapor
import DomainEntity

class AdminGuardAuthenticator: AsyncMiddleware {
    let adminUsers: Set<User.ID>
    init(adminUsers: Set<User.ID>) {
        self.adminUsers = adminUsers
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let user = request.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        guard adminUsers.contains(user.id) else {
            throw Abort(.forbidden)
        }
        return try await next.respond(to: request)
    }
}
