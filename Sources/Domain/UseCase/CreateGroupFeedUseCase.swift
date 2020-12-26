import Foundation
import NIO

public struct CreateGroupFeedUseCase: UseCase {
    public typealias Request = (
        user: User, input: CreateArtistFeed.Request
    )
    public typealias Response = ArtistFeed

    public enum Error: Swift.Error {
        case fanCannotCreateGroupFeed
        case isNotMemberOfGroup
        case onemanStylePerformerShouldBeHostGroup
    }

    public let groupRepository: GroupRepository
    public let userSocialRepository: UserSocialRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        userSocialRepository: UserSocialRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.userSocialRepository = userSocialRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        guard case .artist = request.user.role else {
            return eventLoop.makeFailedFuture(Error.fanCannotCreateGroupFeed)
        }
        let input = request.input
        let feed = groupRepository.createFeed(for: input, authorId: request.user.id)
        return feed.flatMap { feed in
            return notifyArtistFollowers(artist: request.user.id, feed: feed)
                .map { feed }
        }
    }

    func notifyArtistFollowers(artist: User.ID, feed: ArtistFeed) -> EventLoopFuture<Void> {
        let groups = groupRepository.getMemberships(for: artist)
        return groups.flatMap { groups in
            EventLoopFuture.andAllSucceed(
                groups.map {
                    notifyGroupFollowers(group: $0.id, feed: feed)
                }, on: eventLoop)
        }
    }
    func notifyGroupFollowers(group: Group.ID, feed: ArtistFeed) -> EventLoopFuture<Void> {
        let followers = userSocialRepository.followers(selfGroup: group)
        return followers.flatMap { followers in
            EventLoopFuture.andAllSucceed(
                followers.map {
                    notifyGroupFollower(group: group, follower: $0, feed: feed)
                }, on: eventLoop)
        }
    }
    func notifyGroupFollower(group: Group.ID, follower: User.ID, feed: ArtistFeed)
        -> EventLoopFuture<Void>
    {
        let notification = PushNotification(message: "\(feed.author.name) さんが新しい投稿をしました")
        return notificationService.publish(to: follower, notification: notification)
    }
}
