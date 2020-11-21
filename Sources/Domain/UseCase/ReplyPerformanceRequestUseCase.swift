import Foundation
import NIO

public struct ReplyPerformanceRequestUseCase: UseCase {
    public typealias Request = (
        user: User, input: Endpoint.ReplyPerformanceRequest.Request
    )
    public typealias Response = Void

    public enum Error: Swift.Error {
        case fanCannotBePerformer
        case onlyLeaderCanAccept
        case liveNotFound
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
            return eventLoop.makeFailedFuture(Error.fanCannotBePerformer)
        }
        let performanceRequest = liveRepository.find(requestId: request.input.requestId)
        let precondition = performanceRequest.map(\.group.id)
            .flatMap { groupRepository.isLeader(of: $0, member: request.user.id) }
            .flatMapThrowing {
                guard $0 else { throw Error.onlyLeaderCanAccept }
            }
        let status: PerformanceRequest.Status
        switch request.input.reply {
        case .accept: status = .accepted
        case .deny: status = .denied
        }
        return precondition.flatMap {
            liveRepository.updatePerformerStatus(
                requestId: request.input.requestId, status: status
            )
        }
    }
}
