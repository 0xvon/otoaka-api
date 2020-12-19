import Foundation
import NIO

public struct CreateGroupFeedUseCase: UseCase {
    public typealias Request = (
        user: User, input: CreateArtistFeed.Request
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
        return groupRepository.createFeed(for: input, authorId: request.user.id)
    }
}
