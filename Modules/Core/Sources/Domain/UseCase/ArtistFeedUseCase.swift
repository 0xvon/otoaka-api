import Foundation
import NIO

public struct DeleteArtistFeedUseCase: UseCase {
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
