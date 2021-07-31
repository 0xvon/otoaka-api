import Domain
import FluentKit
import Foundation

public class LiveRepository: Domain.LiveRepository {
    private let db: Database
    public init(db: Database) {
        self.db = db
    }

    public enum Error: Swift.Error {
        case liveNotFound
        case ticketNotFound
        case ticketPermissionError
        case ticketAlreadyReserved
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
            title: input.title, style: style, price: input.price, artworkURL: input.artworkURL,
            hostGroupId: input.hostGroupId, authorId: authorId,
            liveHouse: input.liveHouse,
            date: input.date, openAt: input.openAt, startAt: input.startAt,
            piaEventCode: input.piaEventCode, piaReleaseUrl: input.piaReleaseUrl, piaEventUrl: input.piaEventUrl
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
            live.artworkURL = input.artworkURL?.absoluteString
            live.liveHouse = input.liveHouse
            live.date = input.date
            live.openAtV2 = input.openAt
            live.startAtV2 = input.startAt
            live.piaEventCode = input.piaEventCode
            live.piaReleaseUrl = input.piaReleaseUrl?.absoluteString
            live.piaEventUrl = input.piaEventUrl?.absoluteString
            
            return live
        }
        .flatMap { [db] live in live.update(on: db).map { live } }
        return modified.flatMap { [db] in Domain.Live.translate(fromPersistance: $0, on: db) }
    }

    public func getLiveDetail(by id: Domain.Live.ID, selfUerId: Domain.User.ID) -> EventLoopFuture<
        Domain.LiveDetail?
    > {
        let isLiked = LiveLike.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .filter(\.$user.$id == selfUerId.rawValue)
            .count().map { $0 > 0 }
        let likeCount = LiveLike.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .count()
        let ticket = Ticket.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .filter(\.$user.$id == selfUerId.rawValue)
            .filter(\.$status == .reserved)
            .first()
            .optionalFlatMap { [db] in
                Domain.Ticket.translate(fromPersistance: $0, on: db)
            }
        let participants = Ticket.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .filter(\.$status == .reserved)
            .count()
        return Live.find(id.rawValue, on: db).optionalFlatMap { [db] in
            let live = Domain.Live.translate(fromPersistance: $0, on: db)
            return live.and(isLiked).and(participants).and(likeCount).and(ticket)
                .map { ($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1) }
                .map {
                    (
                        live: Domain.Live, isLiked: Bool, participants: Int, likeCount: Int,
                        ticket: Domain.Ticket?
                    ) -> Domain.LiveDetail in
                    return Domain.LiveDetail(
                        live: live, isLiked: isLiked, participants: participants,
                        likeCount: likeCount, ticket: ticket)
                }
        }
    }

    public func getLive(by id: Domain.Live.ID) -> EventLoopFuture<Domain.Live?> {
        Live.find(id.rawValue, on: db).optionalFlatMap { [db] in
            Domain.Live.translate(fromPersistance: $0, on: db)
        }
    }

    public func getParticipants(liveId: Domain.Live.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.User>>  {
        return Ticket.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .filter(\.$status == .reserved)
            .with(\.$user)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<Domain.User>.translate(page: $0, eventLoop: db.eventLoop) {
                    Domain.User.translate(fromPersistance: $0.user, on: db)
                }
            }
    }

    public func reserveTicket(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<
        Domain.Ticket
    > {
        let isLiveExist = Live.find(liveId.rawValue, on: db).map { $0 != nil }
        let hasValidTicket = Ticket.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .filter(\.$user.$id == user.rawValue)
            .filter(\.$status == .reserved)
            .first().map { $0 != nil }

        return isLiveExist.and(hasValidTicket).flatMapThrowing { isLiveExist, hasValidTicket -> Void in
            guard isLiveExist else { throw Error.liveNotFound }
            guard !hasValidTicket else {
                throw Error.ticketAlreadyReserved
            }
            return ()
        }
        .flatMap { [db] _ -> EventLoopFuture<Ticket> in
            let ticket = Ticket(status: .reserved, liveId: liveId.rawValue, userId: user.rawValue)
            return ticket.save(on: db).map { _ in ticket }
        }
        .flatMap { [db] in
            Domain.Ticket.translate(fromPersistance: $0, on: db)
        }
    }

    public func refundTicket(ticketId: Domain.Ticket.ID, user: Domain.User.ID) -> EventLoopFuture<
        Domain.Ticket
    > {
        let ticket = Ticket.find(ticketId.rawValue, on: db)
        return ticket.unwrap(orError: Error.ticketNotFound)
            .guard({ $0.$user.id == user.rawValue }, else: Error.ticketPermissionError)
            .flatMap { [db] ticket -> EventLoopFuture<Ticket> in
                ticket.status = .refunded
                return ticket.update(on: db).map { _ in ticket }
            }
            .flatMap { [db] in
                Domain.Ticket.translate(fromPersistance: $0, on: db)
            }
    }

    public func getUserTickets(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.Ticket>
    > {
        return Ticket.query(on: db).filter(\.$user.$id == userId.rawValue)
            .join(parent: \.$live)
            .sort(Live.self, \.$startAt)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<Domain.Ticket>.translate(page: $0, eventLoop: db.eventLoop) {
                    Domain.Ticket.translate(fromPersistance: $0, on: db)
                }
            }
    }

    public func updatePerformerStatus(
        requestId: Domain.PerformanceRequest.ID,
        status: Domain.PerformanceRequest.Status
    ) -> EventLoopFuture<Void> {
        let request = PerformanceRequest.find(requestId.rawValue, on: db).unwrap(
            orError: Error.requestNotFound)
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
        PerformanceRequest.find(requestId.rawValue, on: db).unwrap(orError: Error.requestNotFound)
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
    public func get(page: Int, per: Int, group: Domain.Group.ID) -> EventLoopFuture<
        Domain.Page<Domain.Live>
    > {
        let lives = LivePerformer.query(on: db)
            .filter(\.$group.$id == group.rawValue)
            .with(\.$live)  //  { $0.with(\.$author).with(\.$hostGroup) }
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

    public func getPendingRequestCount(for user: Domain.User.ID) -> EventLoopFuture<Int> {
        PerformanceRequest.query(on: db)
            .join(Membership.self, on: \PerformanceRequest.$group.$id == \Membership.$group.$id)
            .filter(Membership.self, \.$artist.$id == user.rawValue)
            .filter(Membership.self, \.$isLeader == true)
            .filter(\.$status == .pending)
            .count()
    }

    public func search(query: String, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.Live>
    > {
        let lives = Live.query(on: db).filter(\.$title =~ query)
        return lives.paginate(PageRequest(page: page, per: per)).flatMap { [db] in
            Domain.Page.translate(page: $0, eventLoop: db.eventLoop) {
                Domain.Live.translate(fromPersistance: $0, on: db)
            }
        }
    }

    public func getLiveTickets(until: Date) -> EventLoopFuture<[Domain.Ticket]> {
        let tickets = Ticket.query(on: db)
            .join(parent: \.$live)
            .filter(Live.self, \Live.$startAt > until)
            .all()
        return tickets.flatMapEach(on: db.eventLoop) { [db] in
            Domain.Ticket.translate(fromPersistance: $0, on: db)
        }
    }
}
