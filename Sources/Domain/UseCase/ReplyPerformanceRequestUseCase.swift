import Foundation
import NIO

public struct ReplyPerformanceRequestUseCase: UseCase {
    public typealias Request = (
        user: User, input: Endpoint.ReplyPerformanceRequest.Request
    )
    public typealias Response = Live

    public enum Error: Swift.Error {
        case fanCannotBePerformer
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
            return eventLoop.makeFailedFuture(Error.fanCannotBePerformer)
        }

        fatalError()
    }
}
