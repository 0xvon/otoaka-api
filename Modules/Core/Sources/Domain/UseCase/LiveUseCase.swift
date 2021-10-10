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
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        liveRepository: LiveRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.liveRepository = liveRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
//        guard case .artist = request.user.role else {
//            return eventLoop.makeFailedFuture(Error.fanCannotCreateLive)
//        }
        try validateInput(request: request)
        let input = request.input
//        let precondition = groupRepository.isMember(
//            of: input.hostGroupId, member: request.user.id
//        )
//        .flatMapThrowing {
//            guard $0 else { throw Error.isNotMemberOfHostGroup }
//            return
//        }
        return liveRepository.create(input: input)
        .flatMap { live in
            switch live.style {
            case .oneman(let performer):
                let notification = PushNotification(message: "\(performer.name) のライブ情報が更新されました")
                return notificationService.publish(
                    toGroupFollowers: performer.id, notification: notification
                )
                .map { live }
            case .battle(let performers):
                return EventLoopFuture<Void>.andAllSucceed(performers.map { performer in
                    let notification = PushNotification(message: "\(performer.name) のライブ情報が更新されました")
                    return notificationService.publish(
                        toGroupFollowers: performer.id, notification: notification
                    )
                }, on: eventLoop)
                .map { live }
            case .festival(let performers):
                return EventLoopFuture<Void>.andAllSucceed(performers.map { performer in
                    let notification = PushNotification(message: "\(performer.name) のライブ情報が更新されました")
                    return notificationService.publish(
                        toGroupFollowers: performer.id, notification: notification
                    )
                }, on: eventLoop)
                .map { live }
            }
        }
    }

    func validateInput(request: Request) throws {
        guard request.input.price >= 0 else {
            throw Error.invalidPrice
        }
//        switch request.input.style {
//        case .oneman(let performer):
//            guard request.input.hostGroupId == performer else {
//                throw Error.onemanStylePerformerShouldBeHostGroup
//            }
//        default:
//            break
//        }
    }
}

public struct EditLiveUseCase: UseCase {
    public typealias Request = (
        id: Live.ID, user: User, input: EditLive.Request
    )
    public typealias Response = Live

    public enum Error: Swift.Error {
//        case fanCannotEditLive
        case liveNotFound
//        case isNotMemberOfHostGroup
    }

    public let groupRepository: GroupRepository
    public let liveRepository: LiveRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        liveRepository: LiveRepository,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.liveRepository = liveRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
//        guard case .artist = request.user.role else {
//            return eventLoop.makeFailedFuture(Error.fanCannotEditLive)
//        }
        let live = liveRepository.getLiveDetail(by: request.id, selfUserId: request.user.id)
            .unwrap(orError: Error.liveNotFound)
//        let precondition = live.map(\.live.hostGroup).flatMap { hostGroup in
//            groupRepository.isMember(
//                of: hostGroup.id, member: request.user.id
//            )
//        }
//        .flatMapThrowing {
//            guard $0 else { throw Error.isNotMemberOfHostGroup }
//            return
//        }

        return live.flatMap { _ in
            liveRepository.update(
                id: request.id, input: request.input)
        }
    }
}

public struct FetchLiveUseCase: UseCase {
    public typealias Request = CreateLive.Request
    public typealias Response = Live

    public let liveRepository: LiveRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        liveRepository: LiveRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.liveRepository = liveRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let live = liveRepository.getLive(by: request.piaEventCode!)
        return live.flatMap { live -> EventLoopFuture<Response> in
            if let live = live {
                return liveRepository.update(id: live.id, input: request)
            } else {
                return liveRepository.create(input: request)
                    .flatMap { live in
                        switch live.style {
                        case .oneman(let performer):
                            let notification = PushNotification(message: "\(performer.name) のライブ情報が更新されました")
                            return notificationService.publish(
                                toGroupFollowers: performer.id, notification: notification
                            )
                            .map { live }
                        case .battle(let performers):
                            return EventLoopFuture<Void>.andAllSucceed(performers.map { performer in
                                let notification = PushNotification(message: "\(performer.name) のライブ情報が更新されました")
                                return notificationService.publish(
                                    toGroupFollowers: performer.id, notification: notification
                                )
                            }, on: eventLoop)
                            .map { live }
                        case .festival(let performers):
                            return EventLoopFuture<Void>.andAllSucceed(performers.map { performer in
                                let notification = PushNotification(message: "\(performer.name) のライブ情報が更新されました")
                                return notificationService.publish(
                                    toGroupFollowers: performer.id, notification: notification
                                )
                            }, on: eventLoop)
                            .map { live }
                        }
                    }
            }
        }
    }
}

public struct ReserveLiveTicketUseCase: UseCase {
    public typealias Request = (
        liveId: Live.ID,
        user: User
    )
    public typealias Response = Void

    public enum Error: Swift.Error {
        case artistCannotCreateLive
        case isNotMemberOfHostGroup
    }

    public let liveRepository: LiveRepository
    public let eventLoop: EventLoop

    public init(
        liveRepository: LiveRepository,
        eventLoop: EventLoop
    ) {
        self.liveRepository = liveRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        return liveRepository.reserveTicket(liveId: request.liveId, user: request.user.id)
    }
}
