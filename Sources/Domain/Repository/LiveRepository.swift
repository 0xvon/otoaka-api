import Foundation
import NIO

public protocol LiveRepository {
    func create(input: Endpoint.CreateLive.Request, authorId: Domain.User.ID) -> EventLoopFuture<
        Endpoint.Live
    >
    func findLive(by id: Domain.Live.ID) -> EventLoopFuture<Domain.Live?>

    func join(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<Domain.Ticket>

    func get(page: Int, per: Int) -> EventLoopFuture<Page<Live>>
}
