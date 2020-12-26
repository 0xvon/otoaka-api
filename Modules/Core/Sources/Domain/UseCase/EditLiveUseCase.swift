import Foundation
import NIO

public struct EditLiveUseCase: UseCase {
    public typealias Request = (
        id: Live.ID, user: User, input: EditLive.Request
    )
    public typealias Response = Live

    public enum Error: Swift.Error {
        case fanCannotEditLive
        case liveNotFound
        case isNotMemberOfHostGroup
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
        guard case .artist = request.user.role else {
            return eventLoop.makeFailedFuture(Error.fanCannotEditLive)
        }
        let live = liveRepository.getLiveDetail(by: request.id, selfUerId: request.user.id)
            .unwrap(orError: Error.liveNotFound)
        let precondition = live.map(\.live.hostGroup).flatMap { hostGroup in
            groupRepository.isMember(
                of: hostGroup.id, member: request.user.id
            )
        }
        .flatMapThrowing {
            guard $0 else { throw Error.isNotMemberOfHostGroup }
            return
        }

        return precondition.flatMap {
            liveRepository.update(
                id: request.id, input: request.input,
                authorId: request.user.id)
        }
    }
}
