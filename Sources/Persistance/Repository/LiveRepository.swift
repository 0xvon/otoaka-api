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
                    let futures =
                        performerGroups
                        .map { performerId -> EventLoopFuture<Void> in
                            if performerId == input.hostGroupId {
                                let request = LivePerformer()
                                request.$group.id = performerId.rawValue
                                request.$live.id = liveId
                                return request.save(on: db)
                            } else {
                                let request = PerformanceRequest()
                                request.$group.id = performerId.rawValue
                                request.$live.id = liveId
                                request.status = .pending
                                return request.save(on: db)
                            }
                        }
                    return db.eventLoop.flatten(futures)
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
        requestId: Domain.PerformanceRequest.ID,
        status: Domain.PerformanceRequest.Status
    ) -> EventLoopFuture<Void> {
        let request = PerformanceRequest.find(requestId.rawValue, on: db).unwrap(
            or: Error.requestNotFound)
        return request.flatMap { [db] request in
            request.status = status
            return db.transaction { db -> EventLoopFuture<Void> in
                switch status {
                case .accepted:
                    let performer = LivePerformer()
                    performer.$group.id = request.$group.id
                    performer.$live.id = request.$live.id
                    return request.update(on: db)
                        .flatMap { performer.save(on: db) }
                default:
                    return request.update(on: db)
                }
            }
        }
    }

    public func find(requestId: Domain.PerformanceRequest.ID) -> EventLoopFuture<
        Domain.PerformanceRequest
    > {
        PerformanceRequest.find(requestId.rawValue, on: db).unwrap(or: Error.requestNotFound)
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
    public func get(page: Int, per: Int, group: Domain.Group.ID) -> EventLoopFuture<Domain.Page<Domain.Live>> {
        let lives = LivePerformer.query(on: db)
            .filter(\.$group.$id == group.rawValue)
            .with(\.$live) //  { $0.with(\.$author).with(\.$hostGroup) }
        return lives.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.Live.translate(fromPersistance: $0.live, on: db)
            }
        }
    }

    public func getRequests(for user: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.PerformanceRequest>
    > {
        let performers = PerformanceRequest.query(on: db)
            .join(Membership.self, on: \PerformanceRequest.$group.$id == \Membership.$group.$id)
            .filter(Membership.self, \.$artist.$id == user.rawValue)
            .filter(Membership.self, \.$isLeader == true)
            .with(\.$group).with(\.$live)
        return performers.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.PerformanceRequest.translate(fromPersistance: $0, on: db)
            }
        }
    }
}
