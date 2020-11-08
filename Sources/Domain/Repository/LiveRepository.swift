import Foundation
import NIO

public protocol LiveRepository {
    func create(
        title: String, style: LiveStyle, artworkURL: URL?,
        hostGroupId: Domain.Group.ID,
        authorId: Domain.User.ID,
        openAt: Date?, startAt: Date?, endAt: Date?,
        performerGroups: [Domain.Group.ID]
    ) -> EventLoopFuture<Domain.Live>

    func findLive(by id: Domain.Live.ID) -> EventLoopFuture<Domain.Live?>

    func join(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<Domain.Ticket>

    func get(page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.Live>>
}
