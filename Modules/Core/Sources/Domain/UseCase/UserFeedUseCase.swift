import Foundation
import NIO

public struct DeleteUserFeedUseCase: LegacyUseCase {
    public typealias Request = (id: UserFeed.ID, user: User.ID)
    public typealias Response = Void

    public enum Error: Swift.Error {
        case notAuthor
    }

    public let userRepository: UserRepository
    public let eventLoop: EventLoop

    public init(
        userRepository: UserRepository,
        eventLoop: EventLoop
    ) {
        self.userRepository = userRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let precondition = userRepository.getUserFeed(feedId: request.id).flatMapThrowing {
            guard $0.author.id == request.user else {
                throw Error.notAuthor
            }
            return
        }
        return precondition.flatMap {
            userRepository.deleteFeed(id: request.id)
        }
    }
}

public struct CreateUserFeedUseCase: LegacyUseCase {
    public typealias Request = (
        user: User, input: CreateUserFeed.Request
    )
    public typealias Response = UserFeed

    public let userRepository: UserRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        userRepository: UserRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let input = request.input
        let feed = userRepository.createFeed(for: input, authorId: request.user.id)
        return feed.flatMap { feed in
            let notification = PushNotification(message: "\(feed.author.name) さんが新しい投稿をしました")
            return notificationService.publish(
                toUserFollowers: request.user.id, notification: notification
            )
            .map { feed }
        }
    }
}
