import Foundation
import NIO

public struct DeleteArtistFeedUseCase: LegacyUseCase {
    public typealias Request = (id: ArtistFeed.ID, user: User.ID)
    public typealias Response = Void

    public enum Error: Swift.Error {
        case notAuthor
    }

    public let groupRepository: GroupRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let precondition = groupRepository.getArtistFeed(feedId: request.id).flatMapThrowing {
            guard $0.author.id == request.user else {
                throw Error.notAuthor
            }
            return
        }
        return precondition.flatMap {
            groupRepository.deleteFeed(id: request.id)
        }
    }
}

public struct CreateArtistFeedUseCase: LegacyUseCase {
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
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
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
            let notification = PushNotification(message: "\(feed.author.name) さんが新しい投稿をしました")
            return notificationService.publish(
                toArtistFollowers: request.user.id, notification: notification
            )
            .map { feed }
        }
    }
}
