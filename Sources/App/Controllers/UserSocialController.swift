import Domain
import Foundation
import Persistance
import Vapor

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.UserSocialRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.UserSocialRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct UserSocialController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(
            endpoint: FollowGroup.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(FollowGroup.Request.self)
                return repository.follow(selfUser: user.id, targetGroup: input.id)
                    .map { Empty() }
            })
        try routes.on(
            endpoint: UnfollowGroup.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(UnfollowGroup.Request.self)
                return repository.unfollow(selfUser: user.id, targetGroup: input.id)
                    .map { Empty() }
            })
        try routes.on(
            endpoint: GroupFollowers.self,
            use: injectProvider { req, uri, repository in
                repository.followers(selfGroup: uri.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: FollowingGroups.self,
            use: injectProvider { req, uri, repository in
                repository.followings(selfUser: uri.id, page: uri.page, per: uri.per)
            })
    }
}
