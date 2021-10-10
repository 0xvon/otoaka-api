import Endpoint
import NIO

public protocol UserSocialRepository {
    func follow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func unfollow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func followings(userId: User.ID, selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<GroupFeed>>
    func followers(selfGroup: Group.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func followers(selfGroup: Group.ID) -> EventLoopFuture<[User.ID]>
    func isFollowing(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Bool>
    func followersCount(selfGroup: Domain.Group.ID) -> EventLoopFuture<Int>
    func followingGroupsCount(userId: User.ID) -> EventLoopFuture<Int>
    func followUser(selfUser: User.ID, targetUser: User.ID) -> EventLoopFuture<Void>
    func unfollowUser(selfUser: User.ID, targetUser: User.ID) -> EventLoopFuture<Void>
    func followingUsers(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func block(selfUser: User.ID, target: User.ID) -> EventLoopFuture<Void>
    func unblock(selfUser: User.ID, target: User.ID) -> EventLoopFuture<Void>
    func isBlocking(selfUser: User.ID, target: User.ID) -> EventLoopFuture<Bool>
    func recommendedUsers(selfUser: User, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func userFollowers(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func userFollowers(selfUser: User.ID) -> EventLoopFuture<[User.ID]>
    func isUserFollowing(selfUser: User.ID, targetUser: User.ID) -> EventLoopFuture<Bool>
    func userFollowersCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func followingUsersCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func upcomingLives(userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Page<LiveFeed>>
    func followingGroupFeeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<ArtistFeedSummary>
    >
    func followingUserFeeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<UserFeedSummary>
    >
    func allUserFeeds(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<UserFeedSummary>
    >
    func likedUserFeeds(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<UserFeedSummary>>
    func usersFeedCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func userLikeFeedCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func likeLive(userId: User.ID, liveId: Live.ID) -> EventLoopFuture<Void>
    func unlikeLive(userId: User.ID, liveId: Live.ID) -> EventLoopFuture<Void>
    func likedLive(userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.LiveFeed>>
    func likeUserFeed(userId: User.ID, feedId: UserFeed.ID) -> EventLoopFuture<Void>
    func unlikeUserFeed(userId: User.ID, feedId: UserFeed.ID) -> EventLoopFuture<Void>
    func trendPosts(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostSummary>>
    func followingPosts(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostSummary>>
    func allPosts(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostSummary>>
    func likedPosts(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostSummary>>
    func likePost(userId: User.ID, postId: Post.ID) -> EventLoopFuture<Void>
    func unlikePost(userId: User.ID, postId: Post.ID) -> EventLoopFuture<Void>
    func userPostCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func userLikePostCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func userLikeLiveCount(selfUser: Domain.User.ID) -> EventLoopFuture<Int>
    func getLiveLikedUsers(liveId: Domain.Live.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.User>>
    func getLiveLikedUsers(live: Domain.Live.ID) -> EventLoopFuture<[Domain.User.ID]>
}
