import Domain
import Fluent
import Foundation

public class LiveRepository: Domain.LiveRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    public enum Error: Swift.Error {
        case userNotFound
        case groupNotFound
        case invitationNotFound
    }

    public func create(
        title: String, style: LiveStyle, artworkURL: URL?,
        hostGroupId: Domain.Group.ID,
        authorId: Domain.User.ID,
        openAt: Date?, startAt: Date?, endAt: Date?,
        performerGroups: [Domain.Group.ID]
    ) -> EventLoopFuture<Domain.Live> {
        let live = Live(
            title: title, style: style, artworkURL: artworkURL, hostGroupId: hostGroupId,
            authorId: authorId, openAt: openAt, startAt: startAt, endAt: endAt)
        return db.transaction { (db) -> EventLoopFuture<Void> in
            live.save(on: db)
                .flatMapThrowing { _ in try live.requireID() }
                .flatMap { liveId -> EventLoopFuture<Void> in
                    let performers = performerGroups.map { performerId -> LivePerformer in
                        let relation = LivePerformer()
                        relation.$group.id = performerId.rawValue
                        relation.$live.id = liveId
                        return relation
                    }
                    return db.eventLoop.flatten(performers.map { $0.save(on: db) })
                }
        }
        .flatMap { [db] in Domain.Live.translate(fromPersistance: live, on: db) }
    }

    public func findLive(by id: Domain.Live.ID) -> EventLoopFuture<Domain.Live?> {
        Live.find(id.rawValue, on: db).optionalFlatMap { [db] in
            Domain.Live.translate(fromPersistance: $0, on: db)
        }
    }
}
