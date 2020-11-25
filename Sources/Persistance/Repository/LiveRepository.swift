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
        case requestNotFound
    }

    public func create(input: Endpoint.CreateLive.Request, authorId: Domain.User.ID)
        -> EventLoopFuture<Endpoint.Live>
    {
        let style: LiveStyle
        switch input.style {
        case .oneman: style = .oneman
        case .battle: style = .battle
        case .festival: style = .festival
        }
        let performerGroups = input.style.performers
        let live = Live(
            title: input.title, style: style, artworkURL: input.artworkURL,
            hostGroupId: input.hostGroupId, authorId: authorId,
            openAt: input.openAt, startAt: input.startAt, endAt: input.endAt
        )
        return db.transaction { (db) -> EventLoopFuture<Void> in
            live.save(on: db)
                .flatMapThrowing { _ in try live.requireID() }
                .flatMap { liveId -> EventLoopFuture<Void> in
                    let performers = performerGroups.map { performerId -> LivePerformer in
                        let relation = LivePerformer()
                        relation.$group.id = performerId.rawValue
                        relation.$live.id = liveId
                        relation.status = .pending
                        return relation
                    }
                    return db.eventLoop.flatten(performers.map { $0.save(on: db) })
                }
        }
        .flatMap { [db] in Domain.Live.translate(fromPersistance: live, on: db) }
    }

    public func update(id: Domain.Live.ID, input: EditLive.Request, authorId: Domain.User.ID)
        -> EventLoopFuture<Domain.Live>
    {
        let live = Live.find(id.rawValue, on: db).unwrap(orError: Error.liveNotFound)
        let modified = live.map { live -> Live in
            live.title = input.title
            live.artworkURL = input.artworkURL
            live.openAt = input.openAt
            live.startAt = input.startAt
            live.endAt = input.endAt
            return live
        }
        .flatMap { [db] live in live.save(on: db).map { live } }
        return modified.flatMap { [db] in Domain.Live.translate(fromPersistance: $0, on: db) }
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
    public func updatePerformerStatus(
        requestId: PerformanceRequest.ID,
        status: PerformanceRequest.Status
    ) -> EventLoopFuture<Void> {
        let performer = LivePerformer.find(requestId.rawValue, on: db).unwrap(
            or: Error.requestNotFound)
        return performer.flatMap { [db] performer in
            performer.status = status
            return performer.save(on: db)
        }
    }

    public func find(requestId: PerformanceRequest.ID) -> EventLoopFuture<PerformanceRequest> {
        LivePerformer.find(requestId.rawValue, on: db).unwrap(or: Error.requestNotFound)
            .flatMap { [db] in
                Domain.PerformanceRequest.translate(fromPersistance: $0, on: db)
            }
    }

    public func get(page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.Live>> {
        let lives = Live.query(on: db)
        return lives.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.Live.translate(fromPersistance: $0, on: db)
            }
        }
    }

    public func getRequests(for user: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PerformanceRequest>
    > {
        let performers = LivePerformer.query(on: db)
            .join(Membership.self, on: \LivePerformer.$group.$id == \Membership.$group.$id)
            .filter(Membership.self, \.$artist.$id == user.rawValue)
            .filter(Membership.self, \.$isLeader == true)
        return performers.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.PerformanceRequest.translate(fromPersistance: $0, on: db)
            }
        }
    }
}
