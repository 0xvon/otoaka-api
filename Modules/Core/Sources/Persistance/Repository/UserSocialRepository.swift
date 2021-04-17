import Domain
import FluentKit

public class UserSocialRepository: Domain.UserSocialRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    enum Error: Swift.Error {
        case alreadyFollowing
        case notFollowing
        case targetGroupNotFound
        case feedNotFound
        case notHavingLiveLike
        case notHavingUserFeedLike
    }

    public func follow(
        selfUser: Domain.User.ID,
        targetGroup: Domain.Group.ID
    ) -> EventLoopFuture<Void> {
        let alreadyFollowing = Following.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetGroup.rawValue)
            .count().map { $0 > 0 }
        let isTargetExisting = Group.find(targetGroup.rawValue, on: db)
            .map { $0 != nil }
        let precondition = alreadyFollowing.and(isTargetExisting)
            .flatMapThrowing { alreadyFollowing, isTargetExisting in
                guard !alreadyFollowing else { throw Error.alreadyFollowing }
                guard isTargetExisting else { throw Error.targetGroupNotFound }
                return
            }
        return precondition.flatMap { [db] _ in
            let following = Following()
            following.$user.id = selfUser.rawValue
            following.$target.id = targetGroup.rawValue
            return following.save(on: db)
        }
    }

    public func unfollow(selfUser: Domain.User.ID, targetGroup: Domain.Group.ID) -> EventLoopFuture<
        Void
    > {
        let following = Following.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetGroup.rawValue)
            .first()
        let precondition = following.flatMapThrowing { following -> Following in
            guard let following = following else {
                throw Error.notFollowing
            }
            return following
        }
        return precondition.flatMap { [db] following in
            following.delete(force: true, on: db)
        }
    }

    public func followings(selfUser: Domain.User.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.Group>>
    {
        let followings = Following.query(on: db).filter(\.$user.$id == selfUser.rawValue)
            .with(\.$target)
        return followings.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.Group.translate(fromPersistance: $0.target, on: db)
            }
        }
    }

    public func followers(selfGroup: Domain.Group.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    > {
        let followings = Following.query(on: db).filter(\.$target.$id == selfGroup.rawValue)
            .with(\.$user)
        return followings.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.User.translate(fromPersistance: $0.user, on: db)
            }
        }
    }

    public func followers(selfGroup: Domain.Group.ID) -> EventLoopFuture<[Domain.User.ID]> {
        Following.query(on: db)
            .filter(\.$target.$id == selfGroup.rawValue).all()
            .mapEach {
                Domain.User.ID($0.$user.id)
            }
    }

    public func followersCount(selfGroup: Domain.Group.ID) -> EventLoopFuture<Int> {
        Following.query(on: db).filter(\.$target.$id == selfGroup.rawValue).count()
    }
    
    public func followingGroupsCount(userId: Domain.User.ID) -> EventLoopFuture<Int> {
        Following.query(on: db).filter(\.$user.$id == userId.rawValue).count()
    }

    public func isFollowing(
        selfUser: Domain.User.ID,
        targetGroup: Domain.Group.ID
    ) -> EventLoopFuture<Bool> {
        Following.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetGroup.rawValue)
            .first().map { $0 != nil }
    }
    
    public func followUser(
        selfUser: Domain.User.ID,
        targetUser: Domain.User.ID
    ) -> EventLoopFuture<Void> {
        let alreadyFollowing = UserFollowing.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetUser.rawValue)
            .count().map { $0 > 0 }
        let isTargetExisting = User.find(targetUser.rawValue, on: db)
            .map { $0 != nil }
        let precondition = alreadyFollowing.and(isTargetExisting)
            .flatMapThrowing { alreadyFollowing, isTargetExisting in
                guard !alreadyFollowing else { throw Error.alreadyFollowing }
                guard isTargetExisting else { throw Error.targetGroupNotFound }
                return
            }
        return precondition
            .flatMap { [db] _ in
                let following = UserFollowing()
                following.$user.id = selfUser.rawValue
                following.$target.id = targetUser.rawValue
                return following.save(on: db)
            }
            .flatMap { [db] in
                let notification = UserNotification()
                notification.$user.id = targetUser.rawValue
                notification.isRead = false
                notification.notificationType = .follow
                notification.$followedBy.id = selfUser.rawValue
                return notification.save(on: db)
            }
    }

    public func unfollowUser(selfUser: Domain.User.ID, targetUser: Domain.User.ID) -> EventLoopFuture<
        Void
    > {
        let following = UserFollowing.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetUser.rawValue)
            .first()
        _ = UserNotification.query(on: db)
            .filter(\.$followedBy.$id == selfUser.rawValue)
            .filter(\.$user.$id == targetUser.rawValue)
            .all()
            .flatMap { [db] in $0.delete(force: true, on: db) }
        let precondition = following.flatMapThrowing { following -> UserFollowing in
            guard let following = following else {
                throw Error.notFollowing
            }
            return following
        }
        return precondition.flatMap { [db] following in
            following.delete(force: true, on: db)
        }
    }

    public func followingUsers(selfUser: Domain.User.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.User>>
    {
        let followings = UserFollowing.query(on: db).filter(\.$user.$id == selfUser.rawValue)
            .with(\.$target)
        return followings.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.User.translate(fromPersistance: $0.target, on: db)
            }
        }
    }
    
    public func recommendedUsers(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.User>> {
        // TODO: CHANGE LOGIC
        let users = User.query(on: db)
            .filter(\.$id != selfUser.rawValue)
            .unique()
        return users.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.User.translate(fromPersistance: $0, on: db)
            }
        }
    }

    public func userFollowers(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    > {
        let followings = UserFollowing.query(on: db).filter(\.$target.$id == selfUser.rawValue)
            .with(\.$user)
        return followings.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.User.translate(fromPersistance: $0.user, on: db)
            }
        }
    }

    public func userFollowers(selfUser: Domain.User.ID) -> EventLoopFuture<[Domain.User.ID]> {
        UserFollowing.query(on: db)
            .filter(\.$target.$id == selfUser.rawValue).all()
            .mapEach {
                Domain.User.ID($0.$user.id)
            }
    }

    public func userFollowersCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int> {
        UserFollowing.query(on: db).filter(\.$target.$id == selfUser.rawValue).count()
    }
    
    public func followingUsersCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int> {
        UserFollowing.query(on: db).filter(\.$user.$id == selfUser.rawValue).count()
    }
    
    public func usersFeedCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int> {
        UserFeed.query(on: db).filter(\.$author.$id == selfUser.rawValue).count()
    }
    
    public func userLikeFeedCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int> {
        UserFeedLike.query(on: db).filter(\.$user.$id == selfUser.rawValue).count()
    }

    public func isUserFollowing(
        selfUser: Domain.User.ID,
        targetUser: Domain.User.ID
    ) -> EventLoopFuture<Bool> {
        UserFollowing.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetUser.rawValue)
            .first().map { $0 != nil }
    }

    public func upcomingLives(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.LiveFeed>
    > {
        return Live.query(on: db)
            .join(Following.self, on: \Following.$target.$id == \Live.$hostGroup.$id)
            .filter(Following.self, \Following.$user.$id == userId.rawValue)
            .sort(\.$openAt)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                    let isLiked = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == userId.rawValue)
                        .count().map { $0 > 0 }
                    let hasTicket = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == userId.rawValue)
                        .count().map { $0 > 0 }

                    return Domain.Live.translate(fromPersistance: live, on: db)
                        .and(isLiked).and(hasTicket).map { ($0.0, $0.1, $1) }
                        .map {
                            Domain.LiveFeed(live: $0, isLiked: $1, hasTicket: $2)
                        }
                }
            }
    }

    public func followingGroupFeeds(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.ArtistFeedSummary>
    > {
        return ArtistFeed.query(on: db)
            .join(Membership.self, on: \Membership.$artist.$id == \ArtistFeed.$author.$id)
            .join(Following.self, on: \Following.$target.$id == \Membership.$group.$id)
            .filter(Following.self, \Following.$user.$id == userId.rawValue)
            .with(\.$comments)
            .sort(\.$createdAt, .descending)
            .fields(for: ArtistFeed.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    feed -> EventLoopFuture<ArtistFeedSummary> in
                    return Domain.ArtistFeed.translate(fromPersistance: feed, on: db).map {
                        ArtistFeedSummary(feed: $0, commentCount: feed.comments.count)
                    }
                }
            }
    }
    
    public func followingUserFeeds(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.UserFeedSummary>
    > {
        return UserFeed.query(on: db)
            .join(UserFollowing.self, on: \UserFollowing.$target.$id == \UserFeed.$author.$id, method: .left)
            .group(.or) { // フォローしたユーザーのフィードには自分のフィードも含まれる
                $0.filter(UserFollowing.self, \UserFollowing.$user.$id == userId.rawValue).filter(UserFeed.self, \UserFeed.$author.$id == userId.rawValue)
            }
            .with(\.$comments)
            .with(\.$likes)
            .sort(\.$createdAt, .descending)
            .fields(for: UserFeed.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    feed -> EventLoopFuture<UserFeedSummary> in
                    return Domain.UserFeed.translate(fromPersistance: feed, on: db).map {
                        UserFeedSummary(feed: $0, commentCount: feed.comments.count, likeCount: feed.likes.count, isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(userId.rawValue))
                    }
                }
            }
    }
    
    public func likedUserFeeds(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<UserFeedSummary>> {
        return UserFeed.query(on: db)
            .join(UserFeedLike.self, on: \UserFeedLike.$feed.$id == \UserFeed.$id, method: .left)
            .filter(UserFeedLike.self, \UserFeedLike.$user.$id == selfUser.rawValue)
            .with(\.$comments)
            .with(\.$likes)
            .sort(\.$createdAt, .descending)
            .fields(for: UserFeed.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    feed -> EventLoopFuture<UserFeedSummary> in
                    return Domain.UserFeed.translate(fromPersistance: feed, on: db).map {
                        UserFeedSummary(feed: $0, commentCount: feed.comments.count, likeCount: feed.likes.count, isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(selfUser.rawValue))
                    }
                }
            }
    }
    
    public func allUserFeeds(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.UserFeedSummary>
    > {
        return UserFeed.query(on: db)
            .with(\.$comments)
            .with(\.$likes)
            .sort(\.$createdAt, .descending)
            .fields(for: UserFeed.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                    feed -> EventLoopFuture<UserFeedSummary> in
                    return Domain.UserFeed.translate(fromPersistance: feed, on: db).map {
                        UserFeedSummary(feed: $0, commentCount: feed.comments.count, likeCount: feed.likes.count, isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(selfUser.rawValue))
                    }
                }
            }
    }

    public func likeLive(userId: Domain.User.ID, liveId: Domain.Live.ID) -> EventLoopFuture<Void> {
        let like = LiveLike()
        like.$user.id = userId.rawValue
        like.$live.id = liveId.rawValue
        return like.create(on: db)
    }

    public func unlikeLive(userId: Domain.User.ID, liveId: Domain.Live.ID) -> EventLoopFuture<Void>
    {
        let like = LiveLike.query(on: db).filter(\.$user.$id == userId.rawValue)
            .filter(\.$live.$id == liveId.rawValue)
            .first()
        return like.flatMapThrowing { like -> LiveLike in
            guard let like = like else {
                throw Error.notHavingLiveLike
            }
            return like
        }
        .flatMap { [db] in $0.delete(on: db) }
    }
    
    public func likeUserFeed(userId: Domain.User.ID, feedId: Domain.UserFeed.ID) -> EventLoopFuture<Void> {
        let like = UserFeedLike()
        like.$user.id = userId.rawValue
        like.$feed.id = feedId.rawValue
        return like.create(on: db)
            .flatMap { [db] in
                let feed = UserFeed.find(feedId.rawValue, on: db).unwrap(orError: Error.feedNotFound)
                return feed.flatMapThrowing { feed -> UserNotification in
                    let notification = UserNotification()
                    notification.$likedFeed.id = feedId.rawValue
                    notification.$likedBy.id = userId.rawValue
                    notification.$user.id = feed.$author.id
                    notification.isRead = false
                    notification.notificationType = .like
                    return notification
                }
                .flatMap { [db] in $0.save(on: db) }
            }
    }

    public func unlikeUserFeed(userId: Domain.User.ID, feedId: Domain.UserFeed.ID) -> EventLoopFuture<Void>
    {
        let like = UserFeedLike.query(on: db).filter(\.$user.$id == userId.rawValue)
            .filter(\.$feed.$id == feedId.rawValue)
            .first()
        _ = UserNotification.query(on: db)
            .filter(\.$likedBy.$id == userId.rawValue)
            .filter(\.$likedFeed.$id == feedId.rawValue)
            .delete()
        return like.flatMapThrowing { like -> UserFeedLike in
            guard let like = like else {
                throw Error.notHavingUserFeedLike
            }
            return like
        }
        .flatMap { [db] in $0.delete(on: db) }
    }
}
