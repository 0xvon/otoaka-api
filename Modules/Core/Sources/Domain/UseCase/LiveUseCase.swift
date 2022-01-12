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

    public func callAsFunction(_ request: Request) async throws -> Response {
        try validateInput(request: request)
        let input = request.input
        if let live = try await liveRepository.getLive(title: input.title, liveHouse: input.liveHouse)
            .get()
        {
            // 同じ日程・ライブハウスのライブがあったらperformerとstyleだけ更新して返す
            let editted = try await liveRepository.update(id: live.id, input: input).get()
            try await liveRepository.updateStyle(id: live.id).get()
            return editted
        } else {
            let created = try await liveRepository.create(input: input).get()
            switch created.style {
            case .oneman(let performer):
                let notification = PushNotification(message: "\(performer.name) のライブ情報が更新されました")
                try await notificationService.publish(
                    toGroupFollowers: performer.id, notification: notification
                ).get()
            case .battle(let performers), .festival(let performers):
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for performer in performers {
                        group.addTask {
                            let notification = PushNotification(
                                message: "\(performer.name) のライブ情報が更新されました")
                            try await notificationService.publish(
                                toGroupFollowers: performer.id, notification: notification
                            ).get()
                        }
                    }
                    try await group.waitForAll()
                }
            }
            return created
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

    public func callAsFunction(_ request: Request) async throws -> Response {
        //        guard case .artist = request.user.role else {
        //            return eventLoop.makeFailedFuture(Error.fanCannotEditLive)
        //        }
        //        let precondition = live.map(\.live.hostGroup).flatMap { hostGroup in
        //            groupRepository.isMember(
        //                of: hostGroup.id, member: request.user.id
        //            )
        //        }
        //        .flatMapThrowing {
        //            guard $0 else { throw Error.isNotMemberOfHostGroup }
        //            return
        //        }

        return try await liveRepository.update(id: request.id, input: request.input).get()
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

    public func callAsFunction(_ request: Request) async throws -> Response {
        return try await liveRepository.reserveTicket(liveId: request.liveId, user: request.user.id)
            .get()
    }
}
