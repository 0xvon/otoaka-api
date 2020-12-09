import Endpoint
import NIO

public protocol UserSocialRepository {
    func follow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func unfollow(selfUser: User.ID, targetGroup: Group.ID) -> EventLoopFuture<Void>
    func followings(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<Group>>
    func followers(selfGroup: Group.ID, page: Int, per: Int) -> EventLoopFuture<Page<User>>
    func upcomingLives(userId: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<LiveFeed>>
}
