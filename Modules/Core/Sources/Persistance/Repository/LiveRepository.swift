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
            date: input.date, endDate: input.endDate, openAt: input.openAt, startAt: input.startAt,
            piaEventCode: input.piaEventCode, piaReleaseUrl: input.piaReleaseUrl,
            piaEventUrl: input.piaEventUrl
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

    public func edit(id: Domain.Live.ID, input: EditLive.Request) -> EventLoopFuture<Domain.Live> {
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
            live.date = input.date
            live.endDate = input.endDate
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
        
        // 既存のperformerを全員削除
        let performers = LivePerformer.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .delete(force: true)
            .flatMap { [db] in
                // 新たなperformerを全員追加
                input.style.performers.map { [db] performerId in
                    let performer = LivePerformer()
                    performer.$group.id = performerId.rawValue
                    performer.$live.id = id.rawValue
                    return performer.save(on: db)
                }
                .flatten(on: db.eventLoop)
            }

        return modified.and(performers)
            .flatMap { [db] live, _ in Domain.Live.translate(fromPersistance: live, on: db) }
    }
    
    public func fetch(eventId: String, input: Endpoint.CreateLive.Request) async throws {
        // 1. 同じeventIdのライブを取得
        let live = try await Live.query(on: db).filter(\.$piaEventCode == eventId).first()
        if let live = live {
            _ = try await self.edit(id: .init(live.id!), input: input).get()
        } else {
            _ = try await self.create(input: input).get()
        }
    }
    
    public func merge(for live: Domain.Live.ID, lives: [Domain.Live.ID]) async throws {
        for liveId in lives {
            // LiveLikeをマージ
            let liveLikes = try await LiveLike.query(on: db).filter(\.$live.$id == liveId.rawValue)
                .all()
            
            for like in liveLikes {
                let isLiked = try await LiveLike.query(on: db).filter(\.$live.$id == live.rawValue).filter(\.$user.$id == like.$user.id).first()
                if isLiked == nil {
                    like.$live.id = live.rawValue
                    try await like.update(on: db)
                } else {
                    try await like.delete(force: true, on: db)
                }
            }
            
            // Performerをマージ
            let performers = try await LivePerformer.query(on: db)
                .filter(\.$live.$id == liveId.rawValue)
                .all()
            
            for performer in performers {
                let p = try await LivePerformer.query(on: db).filter(\.$live.$id == live.rawValue).filter(\.$group.$id == performer.$group.id).first()
                if p == nil {
                    performer.$live.id = live.rawValue
                    try await performer.update(on: db)
                } else {
                    try await performer.delete(force: true, on: db)
                }

            }
            
            // Postをマージ
            let posts = try await Post.query(on: db)
                .filter(\.$live.$id == liveId.rawValue)
                .all()
            for post in posts {
                post.$live.id = live.rawValue
                try await post.update(on: db)
            }
            
            // liveを削除
            try await Live.find(liveId.rawValue, on: db)?.delete(force: true, on: db)
        }
    }

    public func getLiveDetail(by id: Domain.Live.ID, selfUserId: Domain.User.ID) async throws
        -> Domain.LiveDetail
    {
        async let isLiked =
            LiveLike.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .filter(\.$user.$id == selfUserId.rawValue)
            .count() > 0
        async let likeCount = LiveLike.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .count()
        async let postCount = Post.query(on: db)
            .filter(\.$live.$id == id.rawValue)
            .count()
        async let participatingFriends: [Domain.User] = {
            let likeUsers = try await LiveLike.query(on: db)
                .join(UserFollowing.self, on: \LiveLike.$user.$id == \UserFollowing.$target.$id)
                .filter(\.$live.$id == id.rawValue)
                .filter(UserFollowing.self, \.$user.$id == selfUserId.rawValue)
                .fields(for: LiveLike.self)
                .with(\LiveLike.$user)
                .all()
                .map { $0.user }
            return try await likeUsers.asyncMap { user in
                try await Domain.User.translate(fromPersistance: user, on: db).get()
            }
        }()
        async let live: Domain.Live = {
            guard let live = try await Live.find(id.rawValue, on: db) else {
                throw Error.liveNotFound
            }
            return try await Domain.Live.translate(fromPersistance: live, on: db).get()
        }()

        return try await Domain.LiveDetail(
            live: live,
            isLiked: isLiked,
            likeCount: likeCount,
            postCount: postCount,
            participatingFriends: participatingFriends
        )
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

    public func getLive(title: String?, date: String?) -> EventLoopFuture<Domain.Live?> {
        Live.query(on: db)
            .filter(\.$title, .custom("LIKE"), "\(title ?? "hogehogehogehoge")")
            .filter(\.$date, .custom("LIKE"), "%\(date ?? "hogehogehogehoge")%")
            .first()
            .optionalFlatMap { [db] in
                Domain.Live.translate(fromPersistance: $0, on: db)
            }
    }

    public func getParticipants(liveId: Domain.Live.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.User>
    > {
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

        return isLiveExist.and(hasValidTicket).flatMapThrowing {
            isLiveExist, hasValidTicket -> Void in
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

    public func refundTicket(liveId: Domain.Live.ID, user: Domain.User.ID) async throws {
        guard
            let ticket = try await Ticket.query(on: db)
                .filter(\.$live.$id == liveId.rawValue).first()
        else { throw Error.ticketNotFound }
        try await ticket.delete(force: true, on: db)
    }

    public func getUserTickets(
        userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int
    ) async throws -> Domain.Page<Domain.LiveFeed> {
        let lives = try await Live.query(on: db)
            .join(Ticket.self, on: \Ticket.$live.$id == \Live.$id)
            .filter(Ticket.self, \.$user.$id == userId.rawValue)
            .sort(Live.self, \.$date)
            .paginate(PageRequest(page: page, per: per))
        return try await Domain.Page<LiveFeed>.translate(page: lives) { live in
            try await Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                .get()
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

    public func get(selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.LiveFeed>
    > {
        let lives = Live.query(on: db)
            .sort(\.$date, .descending)
        return lives.paginate(PageRequest(page: page, per: per))
            .flatMap { [db] in
                Domain.Page<LiveFeed>.translate(page: $0, eventLoop: db.eventLoop) { live in
                    Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                }
            }
    }
    public func get(selfUser: Domain.User.ID, page: Int, per: Int, group: Domain.Group.ID)
        async throws -> Domain.Page<Domain.LiveFeed>
    {
        let lives = try await Live.query(on: db)
            .join(LivePerformer.self, on: \LivePerformer.$live.$id == \Live.$id)
            .filter(LivePerformer.self, \.$group.$id == group.rawValue)
            .sort(\.$date, .descending)
            .paginate(PageRequest(page: page, per: per))
        return try await Domain.Page<LiveFeed>.translate(page: lives) { live in
            try await Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                .get()
        }
    }

    public func getRequests(for user: Domain.User.ID, page: Int, per: Int) async throws
        -> Domain.Page<Domain.PerformanceRequest>
    {
        let performers = try await PerformanceRequest.query(on: db)
            .join(Membership.self, on: \PerformanceRequest.$group.$id == \Membership.$group.$id)
            .filter(Membership.self, \.$artist.$id == user.rawValue)
            .filter(Membership.self, \.$isLeader == true)
            .with(\.$group).with(\.$live)
            .paginate(PageRequest(page: page, per: per))
        return try await Domain.Page.translate(page: performers) {
            try await Domain.PerformanceRequest.translate(fromPersistance: $0, on: db).get()
        }
    }

    public func getPendingRequestCount(for user: Domain.User.ID) async throws -> Int {
        try await PerformanceRequest.query(on: db)
            .join(Membership.self, on: \PerformanceRequest.$group.$id == \Membership.$group.$id)
            .filter(Membership.self, \.$artist.$id == user.rawValue)
            .filter(Membership.self, \.$isLeader == true)
            .filter(\.$status == .pending)
            .count()
    }

    public func search(date: String) -> EventLoopFuture<[Domain.Live]> {
        return Live.query(on: db)
            .filter(Live.self, \.$date == date)
            .all()
            .flatMapEach(on: db.eventLoop) {
                Domain.Live.translate(fromPersistance: $0, on: self.db)
            }
    }

    public func search(
        selfUser: Domain.User.ID, query: String?,
        groupId: Domain.Group.ID?,
        fromDate: String?, toDate: String?,
        page: Int, per: Int
    ) async throws -> Domain.Page<LiveFeed> {
        var searchLive = Live.query(on: db)
            .join(LivePerformer.self, on: \LivePerformer.$live.$id == \Live.$id)
            .join(Group.self, on: \Group.$id == \LivePerformer.$group.$id)

        if let query = query {
            searchLive =
                searchLive
                .group(.or) {
                    $0.filter(Live.self, \.$title, .custom("LIKE"), "%\(query)%")
                        .filter(Group.self, \.$name, .custom("LIKE"), "%\(query)%")
                }
        }
        if let groupId = groupId {
            searchLive =
                searchLive
                .filter(LivePerformer.self, \.$group.$id == groupId.rawValue)
        }
        if let fromDate = fromDate, let toDate = toDate {
            searchLive =
                searchLive
                .filter(Live.self, \.$date >= fromDate)
                .filter(Live.self, \.$date <= toDate)
        }

        let lives =
            try await searchLive
            .unique()
            .fields(for: Live.self)
            .sort(\.$date, .descending)
            .paginate(PageRequest(page: page, per: per))
        return try await Domain.Page<LiveFeed>.translate(page: lives) { live in
            try await Domain.LiveFeed.translate(fromPersistance: live, selfUser: selfUser, on: db)
                .get()
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
    
    public func getLatestLiveDate(by groupId: Domain.Group.ID) async throws -> Date? {
        let live = try await Live.query(on: db)
            .join(LivePerformer.self, on: \LivePerformer.$live.$id == \Live.$id)
            .filter(LivePerformer.self, \.$group.$id == groupId.rawValue)
            .sort(\.$date, .descending)
            .first()
        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            return dateFormatter
        }()
        return live?.date.flatMap(dateFormatter.date(from:))
    }

    public func getLivePosts(liveId: Domain.Live.ID, userId: Domain.User.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.PostSummary>>
    {
        Post.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .group(.or) {
                $0.filter(\.$author.$id == userId.rawValue)
                    .filter(\.$isPrivate != true)
            }
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
                            return Domain.PostSummary(
                                post: $0, commentCount: post.comments.count,
                                likeCount: post.likes.count,
                                isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                    userId.rawValue))
                        }
                }
            }
    }
    
    public func getMyLivePosts(liveId: Domain.Live.ID, userId: Domain.User.ID, page: Int, per: Int)
        -> EventLoopFuture<Domain.Page<Domain.PostSummary>>
    {
        Post.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .filter(\.$author.$id == userId.rawValue)
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
                            return Domain.PostSummary(
                                post: $0, commentCount: post.comments.count,
                                likeCount: post.likes.count,
                                isLiked: post.likes.map { like in like.$user.$id.value! }.contains(
                                    userId.rawValue))
                        }
                }
            }
    }
    
    public func likedCount(liveId: Domain.Live.ID) async throws -> Int {
        return try await LiveLike.query(on: db)
            .filter(\.$live.$id == liveId.rawValue)
            .count()
    }
}
