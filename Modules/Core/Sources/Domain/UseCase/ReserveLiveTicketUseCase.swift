import Foundation
import NIO

public struct ReserveLiveTicketUseCase: UseCase {
    public typealias Request = (
        liveId: Live.ID,
        user: User
    )
    public typealias Response = Ticket

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
