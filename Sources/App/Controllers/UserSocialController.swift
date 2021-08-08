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
        try routes.on(
            endpoint: FollowUser.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(FollowUser.Request.self)
                let notificationService = makePushNotificationService(request: req)
                return repository.followUser(selfUser: user.id, targetUser: input.id)
                    .flatMap {
                        let notification = PushNotification(message: "\(user.name)さんにフォローされました")
                        return notificationService.publish(to: input.id, notification: notification)
                    }
                    .map { Empty() }
            })
        try routes.on(
            endpoint: UnfollowUser.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(UnfollowUser.Request.self)
                return repository.unfollowUser(selfUser: user.id, targetUser: input.id)
                    .map { Empty() }
            })
        try routes.on(
            endpoint: UserFollowers.self,
            use: injectProvider { req, uri, repository in
                repository.userFollowers(selfUser: uri.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: FollowingUsers.self,
            use: injectProvider { req, uri, repository in
                repository.followingUsers(selfUser: uri.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: BlockUser.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(BlockUser.Request.self)
                return repository.block(selfUser: user.id, target: input.id)
                    .map { Empty() }
            })
        try routes.on(
            endpoint: UnblockUser.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(UnblockUser.Request.self)
                return repository.unblock(selfUser: user.id, target: input.id)
                    .map { Empty() }
            })
        try routes.on(
            endpoint: RecommendedUsers.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                return repository.recommendedUsers(selfUser: user, page: uri.page, per: uri.per)
            }
        )
        try routes.on(
            endpoint: GetUpcomingLives.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.upcomingLives(userId: uri.userId, selfUser: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: GetFollowingGroupFeeds.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.followingGroupFeeds(userId: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: GetFollowingUserFeeds.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.followingUserFeeds(userId: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: GetAllUserFeeds.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.allUserFeeds(selfUser: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: GetLikedUserFeeds.self,
            use: injectProvider { req, uri, repository in
                return repository.likedUserFeeds(selfUser: uri.userId, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: LikeLive.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(LikeLive.Request.self)
                return repository.likeLive(userId: user.id, liveId: input.liveId).map { Empty() }
            })
        try routes.on(
            endpoint: UnlikeLive.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(UnlikeLive.Request.self)
                return repository.unlikeLive(userId: user.id, liveId: input.liveId).map { Empty() }
            })
        try routes.on(
            endpoint: Endpoint.GetLikedLive.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                return repository.likedLive(userId: uri.userId, selfUser: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: LikeUserFeed.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(LikeUserFeed.Request.self)
                let notificationService = makePushNotificationService(request: req)
                let userRepository = Persistance.UserRepository(db: req.db)
                return repository.likeUserFeed(userId: user.id, feedId: input.feedId)
                    .and(userRepository.getUserFeed(feedId: input.feedId))
                    .flatMap { _, feed in
                        let notification = PushNotification(
                            message: "\(user.name) さんがあなたの投稿にいいねしました")
                        return notificationService.publish(to: feed.author.id, notification: notification)
                    }
                    .map { Empty() }
            })
        try routes.on(
            endpoint: UnlikeUserFeed.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(Domain.User.self)
                let input = try req.content.decode(UnlikeUserFeed.Request.self)
                return repository.unlikeUserFeed(userId: user.id, feedId: input.feedId).map { Empty() }
            })
        try routes.on(
            endpoint: GetAllPosts.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                return repository.allPosts(userId: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: GetLikedPosts.self,
            use: injectProvider { req, uri, repository in
                return repository.likedPosts(userId: uri.userId, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: GetFollowingPosts.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                return repository.followingPosts(userId: user.id, page: uri.page, per: uri.per)
            })
        try routes.on(
            endpoint: LikePost.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(LikePost.Request.self)
                let notificationService = makePushNotificationService(request: req)
                let userRepository = Persistance.UserRepository(db: req.db)
                return repository.likePost(userId: user.id, postId: input.postId)
                    .and(userRepository.getPost(postId: input.postId))
                    .flatMap { _, post in
                        let notification = PushNotification(message: "\(user.name)が投稿にいいねしました")
                        return notificationService.publish(to: post.author.id, notification: notification)
                    }.map { Empty() }
            })
        try routes.on(
            endpoint: UnlikePost.self,
            use: injectProvider { req, uri, repository in
                let user = try req.auth.require(User.self)
                let input = try req.content.decode(UnlikePost.Request.self)
                return repository.unlikePost(userId: user.id, postId: input.postId).map { Empty() }
            })
        try routes.on(endpoint: GetLiveLikedUsers.self, use: injectProvider { req, uri, repository in
            return repository.getLiveLikedUsers(liveId: uri.liveId, page: uri.page, per: uri.page)
        })
    }
}
