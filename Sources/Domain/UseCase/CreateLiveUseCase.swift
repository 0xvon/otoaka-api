import Foundation
import NIO

public struct CreateLiveUseCase: UseCase {
    public typealias Request = (
        user: User, input: Endpoint.CreateLive.Request
    )
    public typealias Response = Live

    public enum Error: Swift.Error {
        case fanCannotCreateLive
        case isNotMemberOfHostGroup
        case onemanStylePerformerShouldBeHostGroup
        case invalidPrice
    }

    public let groupRepository: GroupRepository
    public let liveRepository: LiveRepository
    public let userSocialRepository: UserSocialRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        liveRepository: LiveRepository,
        userSocialRepository: UserSocialRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.liveRepository = liveRepository
        self.userSocialRepository = userSocialRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        guard case .artist = request.user.role else {
            return eventLoop.makeFailedFuture(Error.fanCannotCreateLive)
        }
        try validateInput(request: request)
        let input = request.input
        let precondition = groupRepository.isMember(
            of: input.hostGroupId, member: request.user.id
        )
        .flatMapThrowing {
            guard $0 else { throw Error.isNotMemberOfHostGroup }
            return
        }
        return precondition.flatMap {
            liveRepository.create(input: input, authorId: request.user.id)
        }
        .flatMap { live in
            notifyGroupFollowers(group: request.input.hostGroupId, live: live)
                .map { _ in live }
        }
    }

    func validateInput(request: Request) throws {
        guard request.input.price >= 0 else {
            throw Error.invalidPrice
        }
        switch request.input.style {
        case .oneman(let performer):
            guard request.input.hostGroupId == performer else {
                throw Error.onemanStylePerformerShouldBeHostGroup
            }
        default:
            break
        }
    }

    func notifyGroupFollowers(group: Group.ID, live: Live) -> EventLoopFuture<Void> {
        let followers = userSocialRepository.followers(selfGroup: group)
        return followers.flatMap { followers in
            EventLoopFuture.andAllSucceed(
                followers.map {
                    notifyGroupFollower(group: group, follower: $0, live: live)
                }, on: eventLoop)
        }
    }
    func notifyGroupFollower(group: Group.ID, follower: User.ID, live: Live)
        -> EventLoopFuture<Void>
    {
        let notification = PushNotification(message: "\(live.hostGroup.name) さんが新しいライブを公開しました")
        return notificationService.publish(to: follower, notification: notification)
    }
}
