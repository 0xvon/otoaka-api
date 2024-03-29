import Domain
import FluentKit
import FluentMySQLDriver
import FluentSQL
import Foundation

public class UserSocialRepository: Domain.UserSocialRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    enum Error: Swift.Error {
        case groupNotFound
        case alreadyFollowing
        case notFollowing
        case alreadyBlocking
        case notBlocking
        case targetGroupNotFound
        case feedNotFound
        case notHavingLiveLike
        case notHavingUserFeedLike
        case usernameAlreadyExists
        case userNotFound
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

    public func updateRecentlyFollowing(
        selfUser: Domain.User.ID,
        groups: [Domain.Group.ID]
    ) -> EventLoopFuture<Void> {
        let reset = self.resetRecentlyFollowing(selfUser: selfUser)
        return reset.flatMap { [db] _ in
            let futures =
                groups
                .map { groupId -> EventLoopFuture<Void> in
                    let request = RecentlyFollowing()
                    request.$target.id = groupId.rawValue
                    request.$user.id = selfUser.rawValue
                    return request.save(on: db)
                }
            return db.eventLoop.flatten(futures)
        }
    }

    public func resetRecentlyFollowing(selfUser: Domain.User.ID) -> EventLoopFuture<
        Void
    > {
        RecentlyFollowing.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .all()
            .flatMapEach(on: db.eventLoop) { [db] following in
                following.delete(force: true, on: db)
            }
            .map { _ in }

    }

    public func followings(userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.GroupFeed>>
    {
        let followings = Following.query(on: db).filter(\.$user.$id == userId.rawValue)
            .with(\.$target)
        return followings.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.GroupFeed.translate(fromPersistance: $0.target, selfUser: selfUser, on: db)
            }
        }
    }

    public func recentlyFollowingGroups(userId: Domain.User.ID, selfUser: Domain.User.ID)
        -> EventLoopFuture<[Domain.GroupFeed]>
    {
        let followings = RecentlyFollowing.query(on: db).filter(\.$user.$id == userId.rawValue)
            .with(\.$target)
        return followings.all().flatMapEach(on: db.eventLoop) { [db] in
            Domain.GroupFeed.translate(fromPersistance: $0.target, selfUser: selfUser, on: db)
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

    public func getLiveLikedUsers(live: Domain.Live.ID) -> EventLoopFuture<[Domain.User.ID]> {
        LiveLike.query(on: db)
            .filter(\.$live.$id == live.rawValue)
            .all()
            .mapEach { Domain.User.ID($0.$user.id) }
    }

    public func frequentlyWatchingGroups(
        userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int
    ) async throws -> Domain.Page<Domain.GroupFeed> {
        // ここだけGroupFeedの情報がselfUserじゃなくてuserIdに紐付いている
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()
        struct WatchingCount: Codable {
            let group_id: UUID
            let watching_count: Int
        }

        if let mysql = db as? SQLDatabase {
            let watchingCounts = try await mysql.raw(
                """
                select live_performers.group_id as group_id, count(*) as watching_count \
                from live_performers \
                inner join live_likes on live_performers.live_id = live_likes.live_id \
                and live_likes.user_id=UNHEX(REPLACE('\(userId.rawValue.uuidString)', '-', '')) \
                inner join lives on lives.id = live_likes.live_id \
                and lives.date < \"\(dateFormatter.string(from: Date()))\" \
                group by live_performers.group_id \
                order by watching_count desc \
                limit \(String(per)) \
                offset \(String((page - 1) * per))
                """
            )
            .all(decoding: WatchingCount.self).get()

            let items = try await watchingCounts.asyncMap { watchingCount -> GroupFeed in
                guard let group = try await Group.find(watchingCount.group_id, on: db).get()
                else {
                    throw Error.groupNotFound
                }
                let feed = try await GroupFeed.translate(
                    fromPersistance: group, selfUser: userId, on: db
                ).get()
                return feed
            }
            return Domain.Page<GroupFeed>(
                items: items,
                metadata: Domain.PageMetadata(page: page, per: per, total: items.count))

        } else {
            // FIXME: Should be unreachable and proven by type system
            return Domain.Page(
                items: [], metadata: Domain.PageMetadata(page: page, per: per, total: 0))
        }

    }

    public func followersCount(selfGroup: Domain.Group.ID) -> EventLoopFuture<Int> {
        Following.query(on: db).filter(\.$target.$id == selfGroup.rawValue).count()
    }

    public func watchingCount(selfGroup: Domain.Group.ID, selfUser: Domain.User.ID)
        -> EventLoopFuture<Int>
    {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()
        return LivePerformer.query(on: db)
            .filter(\.$group.$id == selfGroup.rawValue)
            .join(LiveLike.self, on: \LiveLike.$live.$id == \LivePerformer.$live.$id)
            .join(Live.self, on: \Live.$id == \LivePerformer.$live.$id)
            .filter(Live.self, \.$date < dateFormatter.string(from: Date()))
            .filter(LiveLike.self, \.$user.$id == selfUser.rawValue)
            .count()
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
        return
            precondition
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

    public func unfollowUser(selfUser: Domain.User.ID, targetUser: Domain.User.ID)
        -> EventLoopFuture<
            Void
        >
    {
        let following = UserFollowing.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == targetUser.rawValue)
            .first()
        let precondition = following.flatMapThrowing { following -> UserFollowing in
            guard let following = following else {
                throw Error.notFollowing
            }
            return following
        }
        return precondition.flatMap { [db] following in
            following.delete(force: true, on: db)
        }
        .flatMap { [db] in
            UserNotification.query(on: db)
                .filter(\.$followedBy.$id == selfUser.rawValue)
                .filter(\.$user.$id == targetUser.rawValue)
                .all()
                .flatMap { [db] in $0.delete(force: true, on: db) }
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

    public func block(
        selfUser: Domain.User.ID,
        target: Domain.User.ID
    ) -> EventLoopFuture<Void> {
        let alreadyBlocking = UserBlocking.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == target.rawValue)
            .count().map { $0 > 0 }
        let isTargetExisting = User.find(target.rawValue, on: db)
            .map { $0 != nil }
        let precondition = alreadyBlocking.and(isTargetExisting)
            .flatMapThrowing { alreadyBlocking, isTargetExisting in
                guard !alreadyBlocking else { throw Error.alreadyBlocking }
                guard isTargetExisting else { throw Error.targetGroupNotFound }
                return
            }
        let isFollowing = UserFollowing.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == target.rawValue)
            .count().map { $0 > 0 }

        let unfollow = isFollowing.flatMap { isFollowing -> EventLoopFuture<Void> in
            if isFollowing {
                return self.unfollowUser(selfUser: selfUser, targetUser: target)
            } else {
                return self.db.eventLoop.makeSucceededFuture(())
            }
        }
        return unfollow.flatMap { [db] _ in
            precondition.flatMap { [db] _ in
                let blocking = UserBlocking()
                blocking.$user.id = selfUser.rawValue
                blocking.$target.id = target.rawValue
                return blocking.save(on: db)
            }
        }
    }

    public func unblock(selfUser: Domain.User.ID, target: Domain.User.ID) -> EventLoopFuture<
        Void
    > {
        let blocking = UserBlocking.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == target.rawValue)
            .first()
        let precondition = blocking.flatMapThrowing { blocking -> UserBlocking in
            guard let blocking = blocking else {
                throw Error.notBlocking
            }
            return blocking
        }
        return precondition.flatMap { [db] blocking in
            blocking.delete(force: true, on: db)
        }
    }

    public func isBlocking(
        selfUser: Domain.User.ID,
        target: Domain.User.ID
    ) -> EventLoopFuture<Bool> {
        UserBlocking.query(on: db)
            .filter(\.$user.$id == selfUser.rawValue)
            .filter(\.$target.$id == target.rawValue)
            .first().map { $0 != nil }
    }

    public func recommendedUsers(selfUser: Domain.User, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    > {
        // (=^･ω･^=)
        var users = User.query(on: db)
        if db is SQLDatabase {
            users =
                users
                .join(UserBlocking.self, on: \UserBlocking.$target.$id == \User.$id, method: .left)
                .group(.or) {
                    $0.filter(.sql(raw: "user_blockings.id is NULL"))
                        .filter(UserBlocking.self, \.$user.$id != selfUser.id.rawValue)
                }
                .join(
                    AnotherUserBlocking.self, on: \AnotherUserBlocking.$user.$id == \User.$id,
                    method: .left
                )
                .group(.or) {
                    $0.filter(.sql(raw: "another_user_blockings.id is NULL"))
                        .filter(AnotherUserBlocking.self, \.$target.$id != selfUser.id.rawValue)
                }
                .join(
                    UserFollowing.self, on: \UserFollowing.$target.$id == \User.$id, method: .left
                )
                .group(.or) {
                    $0.filter(.sql(raw: "user_followings.id is NULL"))
                        .filter(UserFollowing.self, \.$user.$id != selfUser.id.rawValue)
                }
        }
        return
            users
            .fields(for: User.self)
            .unique()
            .filter(\.$id != selfUser.id.rawValue)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
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

    public func upcomingLives(userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int)
        -> EventLoopFuture<
            Domain.Page<Domain.LiveFeed>
        >
    {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()
        return Live.query(on: db)
            .filter(Live.self, \.$date >= dateFormatter.string(from: Date()))
            .sort(\.$date)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                    Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                }
            }
    }
    
    public func followingGroupsLives(userId: Domain.User.ID, page: Int, per: Int) async throws -> Domain.Page<Domain.LiveFeed> {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()
        
        let live = try await Live.query(on: db)
            .filter(\.$date >= dateFormatter.string(from: Date()))
            .join(LivePerformer.self, on: \LivePerformer.$live.$id == \Live.$id)
            .join(Following.self, on: \Following.$target.$id == \LivePerformer.$group.$id)
            .filter(Following.self, \Following.$user.$id == userId.rawValue)
            .fields(for: Live.self)
            .sort(\.$date, .ascending)
            .unique()
            .paginate(PageRequest(page: page, per: per))
        
        return try await Domain.Page<Domain.LiveFeed>.translate(page: live) { live in
            try await Domain.LiveFeed.translate(fromPersistance: live, selfUser: userId, on: db).get()
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
            .join(
                UserFollowing.self, on: \UserFollowing.$target.$id == \UserFeed.$author.$id,
                method: .left
            )
            .group(.or) {  // フォローしたユーザーのフィードには自分のフィードも含まれる
                $0.filter(UserFollowing.self, \UserFollowing.$user.$id == userId.rawValue).filter(
                    UserFeed.self, \UserFeed.$author.$id == userId.rawValue)
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
                        UserFeedSummary(
                            feed: $0, commentCount: feed.comments.count,
                            likeCount: feed.likes.count,
                            isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(
                                userId.rawValue))
                    }
                }
            }
    }

    public func likedUserFeeds(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<UserFeedSummary>
    > {
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
                        UserFeedSummary(
                            feed: $0, commentCount: feed.comments.count,
                            likeCount: feed.likes.count,
                            isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(
                                selfUser.rawValue))
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
                        UserFeedSummary(
                            feed: $0, commentCount: feed.comments.count,
                            likeCount: feed.likes.count,
                            isLiked: feed.likes.map { like in like.$user.$id.value! }.contains(
                                selfUser.rawValue))
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

    public func likedLive(
        userId: Domain.User.ID, selfUser: Domain.User.ID, series: Domain.LiveSeries = .all,
        sort: Domain.LiveSortType,
        page: Int, per: Int
    ) -> EventLoopFuture<
        Domain.Page<Domain.LiveFeed>
    > {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()
        var live = Live.query(on: db)
            .join(LiveLike.self, on: \LiveLike.$live.$id == \Live.$id)
            .filter(LiveLike.self, \.$user.$id == userId.rawValue)
        switch series {
        case .all:
            return
                live
                .sort(\.$date, .descending)
                .paginate(PageRequest(page: page, per: per))
                .flatMap { [db] in
                    Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                        Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                    }
                }
        case .future:
            return
                live
                .filter(\.$date >= dateFormatter.string(from: Date()))
                .sort(\.$date, .ascending)
                .paginate(PageRequest(page: page, per: per))
                .flatMap { [db] in
                    Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                        Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                    }
                }
        case .past:
            live = live
                .filter(\.$date < dateFormatter.string(from: Date()))
            switch sort {
            case .group:
                live = live
                    .sort(\.$hostGroup.$id, .ascending)
                    .sort(\.$date, .descending)
            case .year:
                live = live
                    .sort(\.$date, .descending)
            }
            return live.paginate(PageRequest(page: page, per: per))
                .flatMap { [db] in
                    Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                        Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                    }
                }
        }
    }

    public func likeUserFeed(userId: Domain.User.ID, feedId: Domain.UserFeed.ID) -> EventLoopFuture<
        Void
    > {
        let like = UserFeedLike()
        like.$user.id = userId.rawValue
        like.$feed.id = feedId.rawValue
        return like.create(on: db)
            .flatMap { [db] in
                let feed = UserFeed.find(feedId.rawValue, on: db).unwrap(
                    orError: Error.feedNotFound)
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

    public func unlikeUserFeed(userId: Domain.User.ID, feedId: Domain.UserFeed.ID)
        -> EventLoopFuture<Void>
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

    public func trendPosts(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PostSummary>
    > {
        Post.query(on: db)
            .with(\.$comments)
            .with(\.$likes)
            .with(\.$imageUrls)
            .with(\.$tracks)
            .sort(\.$createdAt, .descending)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) { post in
                    return Domain.Post.translate(fromPersistance: post, on: db)
                        .map {
                            return Domain.PostSummary(
                                post: $0, commentCount: post.comments.count,
                                likeCount: post.likes.count,
                                isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                    userId.rawValue))
                        }
                }
            }
    }

    public func followingPosts(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PostSummary>
    > {
        Post.query(on: db)
            .join(
                UserFollowing.self, on: \UserFollowing.$target.$id == \Post.$author.$id,
                method: .left
            )
            .group(.or) {  // フォローしたユーザーのフィードには自分のフィードも含まれる
                $0.filter(UserFollowing.self, \UserFollowing.$user.$id == userId.rawValue).filter(
                    Post.self, \Post.$author.$id == userId.rawValue)
            }
            .sort(\.$createdAt, .descending)
            .with(\.$comments)
            .with(\.$likes)
            .with(\.$imageUrls)
            .with(\.$tracks)
            .fields(for: Post.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) { post in
                    return Domain.Post.translate(fromPersistance: post, on: db)
                        .map {
                            return Domain.PostSummary(
                                post: $0, commentCount: post.comments.count,
                                likeCount: post.likes.count,
                                isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                    userId.rawValue))
                        }
                }
            }
    }

    public func allPosts(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PostSummary>
    > {
        Post.query(on: db)
            .sort(\.$createdAt, .descending)
            .with(\.$comments)
            .with(\.$likes)
            .with(\.$imageUrls)
            .with(\.$tracks)
            .fields(for: Post.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) { post in
                    return Domain.Post.translate(fromPersistance: post, on: db)
                        .map {
                            return Domain.PostSummary(
                                post: $0, commentCount: post.comments.count,
                                likeCount: post.likes.count,
                                isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                    userId.rawValue))
                        }
                }
            }
    }

    public func likedPosts(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PostSummary>
    > {
        return Post.query(on: db)
            .join(PostLike.self, on: \PostLike.$post.$id == \Post.$id, method: .left)
            .filter(PostLike.self, \.$user.$id == userId.rawValue)
            .sort(\.$createdAt, .descending)
            .with(\.$comments)
            .with(\.$likes)
            .with(\.$imageUrls)
            .with(\.$tracks)
            .fields(for: Post.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) { post in
                    return Domain.Post.translate(fromPersistance: post, on: db)
                        .map {
                            return Domain.PostSummary(
                                post: $0, commentCount: post.comments.count,
                                likeCount: post.likes.count,
                                isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                    userId.rawValue))
                        }
                }
            }
    }

    public func likePost(userId: Domain.User.ID, postId: Domain.Post.ID) -> EventLoopFuture<Void> {
        let like = PostLike()
        like.$post.id = postId.rawValue
        like.$user.id = userId.rawValue
        return like.create(on: db)
            .flatMap { [db] in
                let post = Post.find(postId.rawValue, on: db).unwrap(orError: Error.feedNotFound)
                return post.flatMapThrowing { post -> UserNotification? in
                    if post.$author.id == userId.rawValue {
                        return nil
                    }
                    let notification = UserNotification()
                    notification.$likedPost.id = postId.rawValue
                    notification.$likedBy.id = userId.rawValue
                    notification.$user.id = post.$author.id
                    notification.isRead = false
                    notification.notificationType = .like_post
                    return notification
                }
                .optionalFlatMap { [db] in $0.save(on: db) }
                .map { _ in return }
            }
    }

    public func unlikePost(userId: Domain.User.ID, postId: Domain.Post.ID) -> EventLoopFuture<Void>
    {
        let like = PostLike.query(on: db)
            .filter(\.$user.$id == userId.rawValue)
            .filter(\.$post.$id == postId.rawValue)
            .first()
        _ = UserNotification.query(on: db)
            .filter(\.$likedBy.$id == userId.rawValue)
            .filter(\.$likedPost.$id == postId.rawValue)
            .delete()

        return like.flatMapThrowing { like -> PostLike in
            guard let like = like else { throw Error.notHavingUserFeedLike }
            return like
        }.flatMap { [db] in $0.delete(force: true, on: db) }
    }

    public func userPostCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int> {
        Post.query(on: db).filter(\.$author.$id == selfUser.rawValue).count()
    }

    public func userLikePostCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int> {
        PostLike.query(on: db).filter(\.$user.$id == selfUser.rawValue).count()
    }

    public func userLikeLiveCount(selfUser: Domain.User.ID, type: Domain.LiveSeries = .all)
        -> EventLoopFuture<Int>
    {
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()
        let like = LiveLike.query(on: db).filter(\.$user.$id == selfUser.rawValue)

        switch type {
        case .all: return like.count()
        case .future:
            return
                like
                .join(Live.self, on: \Live.$id == \LiveLike.$live.$id)
                .filter(Live.self, \.$date >= dateFormatter.string(from: Date()))
                .count()
        case .past:
            return
                like
                .join(Live.self, on: \Live.$id == \LiveLike.$live.$id)
                .filter(Live.self, \.$date < dateFormatter.string(from: Date()))
                .count()
        }
    }

    public func getLiveLikedUsers(liveId: Domain.Live.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    > {
        let likes = LiveLike.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .with(\.$user)

        return
            likes
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<Domain.User>.translate(page: $0, eventLoop: db.eventLoop) {
                    Domain.User.translate(fromPersistance: $0.user, on: db)
                }
            }
    }

    public func getLikedLiveTransition(userId: Domain.User.ID) -> EventLoopFuture<
        Domain.LiveTransition
    > {
        struct LikeCount: Codable {
            let year: String
            let uid: UUID
            let like_count: Int
        }
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy"
            return dateFormatter
        }()
        if let mysql = db as? SQLDatabase {
            return mysql.raw(
                """
                select substring(lives.date, 1, 4) as year, live_likes.user_id as uid, count(*) as like_count \
                from live_likes \
                inner join lives on live_likes.live_id = lives.id \
                group by substring(lives.date, 1, 4), live_likes.user_id \
                having year <= \"\(dateFormatter.string(from: Date()))\" \
                and uid=UNHEX(REPLACE('\(userId.rawValue.uuidString)', '-', '')) \
                order by year asc
                """
            )
            .all(decoding: LikeCount.self)
            .flatMap { [db] (count: [LikeCount]) -> EventLoopFuture<LiveTransition> in
                let year = count.map { $0.year }
                let like_count = count.map { $0.like_count }
                return db.eventLoop.makeSucceededFuture(
                    Domain.LiveTransition(yearLabel: year, liveParticipatingCount: like_count))
            }
        } else {
            return db.eventLoop.makeSucceededFuture(
                Domain.LiveTransition(yearLabel: [], liveParticipatingCount: []))
        }
    }

    public func isUsernameExists(username: String) -> EventLoopFuture<Bool> {
        Username.query(on: db)
            .filter(\.$username == username)
            .count()
            .map { $0 > 0 }
    }

    public func registerUsername(userId: Domain.User.ID, username: String) -> EventLoopFuture<Void>
    {
        let precondition = self.isUsernameExists(username: username)
            .flatMapThrowing {
                guard !$0 else { throw Error.usernameAlreadyExists }
                return
            }

        return precondition.flatMap { [db] in
            _ = Username.query(on: db)
                .filter(\.$user.$id == userId.rawValue)
                .delete()

            let new = Username()
            new.$user.id = userId.rawValue
            new.username = username
            return new.create(on: db)
        }
    }

    public func getUserByUsername(username: String) -> EventLoopFuture<Domain.User> {
        User.query(on: db)
            .join(Username.self, on: \Username.$user.$id == \User.$id)
            .filter(Username.self, \.$username == username)
            .fields(for: User.self)
            .first()
            .unwrap(orError: Error.userNotFound)
            .flatMap { [db] in Domain.User.translate(fromPersistance: $0, on: db) }
    }
}
