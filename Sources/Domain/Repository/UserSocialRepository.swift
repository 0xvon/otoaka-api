import Endpoint
import NIO

public protocol UserSocialRepository {
    func follow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func unfollow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func followings(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<Group>>
    func followers(selfGroup: Group.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func isFollowing(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Bool>
    func followersCount(selfGroup: Domain.Group.ID) -> EventLoopFuture<Int>
    func upcomingLives(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<LiveFeed>>
    func followingGroupFeeds(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<ArtistFeed>
    >
    func likeLive(userId: User.ID, liveId: Live.ID) -> EventLoopFuture<Void>
    func unlikeLive(userId: User.ID, liveId: Live.ID) -> EventLoopFuture<Void>
}
