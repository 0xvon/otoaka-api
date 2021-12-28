import Domain
import Endpoint
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.SocialTipRepository) async throws -> T
)
    -> ((Request, URI) async throws -> T)
{
    return { req, uri in
        let repository = Persistance.SocialTipRepository(db: req.db)
        return try await handler(req, uri, repository)
    }
}

struct SocialTipController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(endpoint: Endpoint.SendSocialTip.self, use: injectProvider { req, uri, repository in
            let user = try req.auth.require(Domain.User.self)
            let request = try req.content.decode(Endpoint.SendSocialTip.Request.self)
            return try await repository.send(userId: user.id, request: request)
        })
        try routes.on(endpoint: Endpoint.GetAllTips.self, use: injectProvider { req, uri, repository in
            return try await repository.get(page: uri.page, per: uri.per)
        })
        try routes.on(endpoint: Endpoint.GetUserTips.self, use: injectProvider { req, uri, repository in
            return try await repository.get(userId: uri.userId, page: uri.page, per: uri.per)
        })
        try routes.on(endpoint: Endpoint.GetGroupTips.self, use: injectProvider { req, uri, repository in
            return try await repository.get(groupId: uri.groupId, page: uri.page, per: uri.per)
        })
        try routes.on(endpoint: Endpoint.GetGroupTipFromUserRanking.self, use: injectProvider { req, uri, repository in
            return try await repository.groupTipRanking(groupId: uri.groupId)
        })
        try routes.on(endpoint: Endpoint.GetUserTipToGroupRanking.self, use: injectProvider { req, uri, repository in
            return try await repository.userTipRanking(userId: uri.userId)
        })
    }
}

extension Endpoint.SocialTip: Content {}
extension Endpoint.UserTip: Content {}
extension Endpoint.GroupTip: Content {}
