import Domain
import Fluent
import Foundation

public class LiveRepository: Domain.LiveRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    public enum Error: Swift.Error {
        case liveNotFound
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
    public func join(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<Domain.Ticket>
    {
        let isLiveExist = Live.find(liveId.rawValue, on: db).map { $0 != nil }
        return isLiveExist.flatMapThrowing { isLiveExist -> Void in
            guard isLiveExist else { throw Error.liveNotFound }
            return ()
        }
        .flatMap { [db] _ -> EventLoopFuture<Ticket> in
            let ticket = Ticket(status: .registered, liveId: liveId.rawValue, userId: user.rawValue)
            return ticket.save(on: db).map { _ in ticket }
        }
        .flatMap { [db] in
            Domain.Ticket.translate(fromPersistance: $0, on: db)
        }
    }
    
    public func get(page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.Live>> {
        let lives = Live.query(on: db)
        return lives.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            let metadata = Domain.PageMetadata(page: $0.metadata.page, per: $0.metadata.per, total: $0.metadata.total)
            let items = $0.items.map { Domain.Live.translate(fromPersistance: $0, on: db) }.flatten(on: db.eventLoop)
            return items.map { Domain.Page(items: $0, metadata: metadata) }
        }
    }
}
