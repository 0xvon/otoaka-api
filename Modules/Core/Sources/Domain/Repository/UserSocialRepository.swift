import Endpoint
import NIO

public protocol UserSocialRepository {
    func follow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func unfollow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func followings(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<Group>>
    func followers(selfGroup: Group.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func followers(selfGroup: Group.ID) -> EventLoopFuture<[User.ID]>
    func isFollowing(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Bool>
    func followersCount(selfGroup: Domain.Group.ID) -> EventLoopFuture<Int>
    func followUser(selfUser: User.ID, targetUser: User.ID) -> EventLoopFuture<Void>
    func unfollowUser(selfUser: User.ID, targetUser: User.ID) -> EventLoopFuture<Void>
    func followingUsers(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func userFollowers(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func userFollowers(selfUser: User.ID) -> EventLoopFuture<[User.ID]>
    func isUserFollowing(selfUser: User.ID, targetUser: User.ID) -> EventLoopFuture<Bool>
    func userFollowersCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func upcomingLives(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<LiveFeed>>
    func followingGroupFeeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<ArtistFeedSummary>
    >
    func followingUserFeeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<UserFeedSummary>
    >
    func allUserFeeds(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<UserFeedSummary>
    >
    func likeLive(userId: User.ID, liveId: Live.ID) -> EventLoopFuture<Void>
    func unlikeLive(userId: User.ID, liveId: Live.ID) -> EventLoopFuture<Void>
    func likeUserFeed(userId: User.ID, feedId: UserFeed.ID) -> EventLoopFuture<Void>
    func unlikeUserFeed(userId: User.ID, feedId: UserFeed.ID) -> EventLoopFuture<Void>
}
