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
        case notHavingLiveLike
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

    public func isFollowing(
        selfUser: Domain.User.ID,
        targetGroup: Domain.Group.ID
    ) -> EventLoopFuture<Bool> {
        Following.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetGroup.rawValue)
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
}