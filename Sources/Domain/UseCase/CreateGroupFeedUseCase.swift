import Foundation
import NIO

public struct CreateGroupFeedUseCase: UseCase {
    public typealias Request = (
        user: User, input: CreateGroupFeed.Request
    )
    public typealias Response = GroupFeed

    public enum Error: Swift.Error {
        case fanCannotCreateGroupFeed
        case isNotMemberOfGroup
        case onemanStylePerformerShouldBeHostGroup
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
        guard case .artist = request.user.role else {
            return eventLoop.makeFailedFuture(Error.fanCannotCreateGroupFeed)
        }
        let input = request.input
        let precondition = groupRepository.isMember(
            of: input.groupId, member: request.user.id
        )
        .flatMapThrowing {
            guard $0 else { throw Error.isNotMemberOfGroup }
            return
        }
        return precondition.flatMap {
            groupRepository.createFeed(for: input, authorId: request.user.id)
        }
    }
}
