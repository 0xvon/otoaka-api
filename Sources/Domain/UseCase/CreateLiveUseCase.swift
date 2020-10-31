import NIO
import Foundation

public struct CreateLiveUseCase: UseCase {
    public typealias Request = (
        user: User,
        title: String, style: LiveStyle, artworkURL: URL?,
        hostGroupId: Domain.Group.ID,
        openAt: Date?, startAt: Date?, endAt: Date?,
        performerGroups: [Domain.Group.ID]
    )
    public typealias Response = Live

    public enum Error: Swift.Error {
        case fanCannotCreateLive
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
            return eventLoop.makeFailedFuture(Error.fanCannotCreateLive)
        }
        let precondition = groupRepository.isMember(of: request.hostGroupId, member: request.user.id)
            .flatMapThrowing {
                guard $0 else { throw Error.isNotMemberOfHostGroup }
                return
            }
        return precondition.flatMap {
            liveRepository.create(
                title: request.title, style: request.style,
                artworkURL: request.artworkURL,
                hostGroupId: request.hostGroupId,
                authorId: request.user.id,
                openAt: request.openAt, startAt: request.startAt, endAt: request.endAt,
                performerGroups: request.performerGroups
            )
        }
    }
}
