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
        case eventCodeNotFound
        case requestNotFound
    }

    public func create(input: Endpoint.CreateLive.Request)
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
            title: input.title,
            style: style,
            price: input.price,
            artworkURL: input.artworkURL,
            hostGroupId: input.hostGroupId,
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
                            let request = LivePerformer()
                            request.$group.id = performerId.rawValue
                            request.$live.id = liveId
                            return request.save(on: db)
                        }
                    return db.eventLoop.flatten(futures)
                }
        }
        .flatMap { [db] in Domain.Live.translate(fromPersistance: live, on: db) }
    }

    public func update(id: Domain.Live.ID, input: EditLive.Request)
        -> EventLoopFuture<Domain.Live>
    {
        let live = Live.find(id.rawValue, on: db)
            .unwrap(orError: Error.liveNotFound)
        
        let style: LiveStyle
        switch input.style {
        case .oneman: style = .oneman
        case .battle: style = .battle
        case .festival: style = .festival
        }
        let modified = live.map { (live) -> Live in
            live.title = input.title
            live.style = style
            live.price = input.price
            live.artworkURL = input.artworkURL?.absoluteString
            live.$hostGroup.id = input.hostGroupId.rawValue
            live.liveHouse = input.liveHouse
            live.openAtV2 = input.openAt
            live.startAtV2 = input.startAt
            live.piaEventCode = input.piaEventCode
            live.piaReleaseUrl = input.piaReleaseUrl?.absoluteString
            live.piaEventUrl = input.piaEventUrl?.absoluteString
            return live
        }
        .flatMap { [db] live in
            live.update(on: db).map { live }
        }
        
        let performers = input.style.performers.map { [db] performerId in
            LivePerformer.query(on: db)
                .filter(\.$live.$id == id.rawValue)
                .filter(\.$group.$id == performerId.rawValue)
                .first()
                .unwrap(orElse: {
                    let performer = LivePerformer()
                    performer.$group.id = performerId.rawValue
                    performer.$live.id = id.rawValue
                    _ = performer.save(on: db)
                    return performer
                })
        }
        .flatten(on: db.eventLoop)
        
        return modified.and(performers)
            .flatMap { [db] live, _ in Domain.Live.translate(fromPersistance: live, on: db) }
    }
    
    public func fetch(input: Domain.CreateLive.Request) -> EventLoopFuture<Domain.Live> {
        let live = self.getLive(by: input.piaEventCode!)
        return live.flatMap { live -> EventLoopFuture<Domain.Live> in
            if let live = live {
                return self.update(id: live.id, input: input)
            } else {
                return self.create(input: input)
            }
        }
    }

    public func getLiveDetail(by id: Domain.Live.ID, selfUserId: Domain.User.ID) -> EventLoopFuture<
        Domain.LiveDetail?
    > {
        let isLiked = LiveLike.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .filter(\.$user.$id == selfUserId.rawValue)
            .count().map { $0 > 0 }
        let likeCount = LiveLike.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .count()
        let ticket = Ticket.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .filter(\.$user.$id == selfUserId.rawValue)
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
    
    public func getLive(by piaEventCode: String) -> EventLoopFuture<Domain.Live?> {
        Live.query(on: db)
            .filter(\.$piaEventCode == piaEventCode)
            .first()
            .optionalFlatMap { [db] in
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
        Void
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
        .flatMap { [db] _ -> EventLoopFuture<Void> in
            let ticket = Ticket(status: .reserved, liveId: liveId.rawValue, userId: user.rawValue)
            return ticket.save(on: db)
        }
    }

    public func refundTicket(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<
        Void
    > {
        let ticket = Ticket.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .first()
            
        return ticket
            .flatMapThrowing { [db] ticket -> Void in
                guard let ticket = ticket else { throw Error.ticketNotFound }
                _ = ticket.delete(on: db)
            }
    }

    public func getUserTickets(userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.LiveFeed>
    > {
        return Live.query(on: db)
            .join(Ticket.self, on: \Ticket.$live.$id == \Live.$id)
            .filter(Ticket.self, \.$user.$id == userId.rawValue)
            .sort(Live.self, \.$date)
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                    let isLiked = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let hasTicket = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let likeCount = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let participantCount = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let postCount = Post.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()

                    return Domain.Live.translate(fromPersistance: live, on: db)
                        .and(isLiked).and(hasTicket).and(likeCount).and(participantCount).and(postCount).map { ( $0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1) }
                        .map {
                            Domain.LiveFeed(live: $0, isLiked: $1, hasTicket: $2, likeCount: $3, participantCount: $4, postCount: $5)
                        }
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

    public func get(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.LiveFeed>> {
        let lives = Live.query(on: db)
            .sort(\.$date, .descending)
        return lives.paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                    let isLiked = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let hasTicket = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let likeCount = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let participantCount = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let postCount = Post.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()

                    return Domain.Live.translate(fromPersistance: live, on: db)
                        .and(isLiked).and(hasTicket).and(likeCount).and(participantCount).and(postCount).map { ( $0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1) }
                        .map {
                            Domain.LiveFeed(live: $0, isLiked: $1, hasTicket: $2, likeCount: $3, participantCount: $4, postCount: $5)
                        }
                }
            }
    }
    public func get(selfUser: Domain.User.ID, page: Int, per: Int, group: Domain.Group.ID) -> EventLoopFuture<
        Domain.Page<Domain.LiveFeed>
    > {
        let lives = Live.query(on: db)
            .join(LivePerformer.self, on: \LivePerformer.$live.$id == \Live.$id)
            .filter(LivePerformer.self, \.$group.$id == group.rawValue)
            .sort(\.$date, .descending)
        return lives.paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                    let isLiked = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let hasTicket = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let likeCount = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let participantCount = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let postCount = Post.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()

                    return Domain.Live.translate(fromPersistance: live, on: db)
                        .and(isLiked).and(hasTicket).and(likeCount).and(participantCount).and(postCount).map { ( $0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1) }
                        .map {
                            Domain.LiveFeed(live: $0, isLiked: $1, hasTicket: $2, likeCount: $3, participantCount: $4, postCount: $5)
                        }
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

    public func search(selfUser: Domain.User.ID, query: String, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.LiveFeed>
    > {
        let lives = Live.query(on: db)
            .join(LivePerformer.self, on: \LivePerformer.$live.$id == \Live.$id)
            .join(Group.self, on: \Group.$id == \LivePerformer.$group.$id)
            .group(.or) {
                $0.filter(Live.self, \.$title, .custom("LIKE"), "%\(query)%")
                    .filter(Group.self, \.$name, .custom("LIKE"), "%\(query)%")
            }
            .unique()
            .fields(for: Live.self)
            .sort(\.$date, .descending)
        return lives.paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                    let isLiked = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let hasTicket = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .filter(\.$user.$id == selfUser.rawValue)
                        .count().map { $0 > 0 }
                    let likeCount = LiveLike.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let participantCount = Ticket.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()
                    let postCount = Post.query(on: db)
                        .filter(\.$live.$id == live.id!)
                        .count()

                    return Domain.Live.translate(fromPersistance: live, on: db)
                        .and(isLiked).and(hasTicket).and(likeCount).and(participantCount).and(postCount).map { ( $0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1) }
                        .map {
                            Domain.LiveFeed(live: $0, isLiked: $1, hasTicket: $2, likeCount: $3, participantCount: $4, postCount: $5)
                        }
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
    
    public func getLivePosts(liveId: Domain.Live.ID, userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.PostSummary>> {
        Post.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .sort(\.$createdAt, .descending)
            .with(\.$comments)
            .with(\.$likes)
            .with(\.$imageUrls)
            .with(\.$tracks)
            .fields(for: Post.self)
            .unique()
            .paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page.translate(page: $0, eventLoop: db.eventLoop) { post in
                    return Domain.Post.translate(fromPersistance: post, on: db)
                        .map {
                            return Domain.PostSummary(post: $0, commentCount: post.comments.count, likeCount: post.likes.count, isLiked: post.likes.map { like in like.$user.$id.value! }.contains(userId.rawValue))
                    }
                }
            }
    }
}
