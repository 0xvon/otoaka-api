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
}
