import Domain
import FluentKit
import Foundation

enum LiveStyle: String, Codable {
    case oneman, battle, festival
}

final class Live: Model {
    static let schema = "lives"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Enum(key: "style")
    var style: LiveStyle

    @Field(key: "price")
    var price: Int

    @OptionalField(key: "artwork_url")
    var artworkURL: String?

    @Parent(key: "host_group_id")
    var hostGroup: Group

    @OptionalParent(key: "author_id")
    var author: User?

    @OptionalField(key: "live_house")
    var liveHouse: String?

    @Timestamp(key: "open_at", on: .none)
    var openAt: Date?
    @Timestamp(key: "start_at", on: .none)
    var startAt: Date?
    @Timestamp(key: "end_at", on: .none)
    var endAt: Date?

    @OptionalField(key: "date")
    var date: String?
    @OptionalField(key: "end_date")
    var endDate: String?
    @OptionalField(key: "open_at_v2")
    var openAtV2: String?
    @OptionalField(key: "start_at_v2")
    var startAtV2: String?

    @OptionalField(key: "pia_event_code")
    var piaEventCode: String?

    @OptionalField(key: "pia_release_url")
    var piaReleaseUrl: String?

    @OptionalField(key: "pia_event_url")
    var piaEventUrl: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        title: String, style: LiveStyle,
        price: Int, artworkURL: URL?,
        hostGroupId: Domain.Group.ID,
        authorId: Domain.User.ID? = nil, liveHouse: String?,
        date: String?, endDate: String?, openAt: String?, startAt: String?,
        piaEventCode: String?, piaReleaseUrl: URL?, piaEventUrl: URL?
    ) {
        self.id = id
        self.title = title
        self.style = style
        self.price = price
        self.artworkURL = artworkURL?.absoluteString
        self.$hostGroup.id = hostGroupId.rawValue
        self.$author.id = authorId?.rawValue
        self.liveHouse = liveHouse
        self.openAt = nil
        self.startAt = nil
        self.endAt = nil
        self.date = date
        self.endDate = endDate
        self.openAtV2 = openAt
        self.startAtV2 = startAt
        self.piaEventCode = piaEventCode
        self.piaReleaseUrl = piaReleaseUrl?.absoluteString
        self.piaEventUrl = piaEventUrl?.absoluteString
    }
}

final class PerformanceRequest: Model {
    static let schema = "performance_requests"
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "live_id")
    var live: Live

    @Parent(key: "group_id")
    var group: Group

    @Field(key: "status")
    var status: Domain.PerformanceRequest.Status
}

final class LivePerformer: Model {
    static let schema = "live_performers"
    @ID(key: .id)
    var id: UUID?

    @Parent(key: "live_id")
    var live: Live

    @Parent(key: "group_id")
    var group: Group
}

extension Endpoint.PerformanceRequest {
    static func translate(fromPersistance entity: PerformanceRequest, on db: Database)
        -> EventLoopFuture<Self>
    {
        let eventLoop = db.eventLoop
        let id = eventLoop.submit { try entity.requireID() }
        let live = entity.$live.get(on: db).flatMap {
            Endpoint.Live.translate(fromPersistance: $0, on: db)
        }
        let group = entity.$group.get(on: db).flatMap {
            Endpoint.Group.translate(fromPersistance: $0, on: db)
        }
        return id.and(live).and(group).map { ($0.0, $0.1, $1) }.map {
            Endpoint.PerformanceRequest(
                id: ID($0), status: entity.status, live: $1, group: $2
            )
        }
    }
}

extension Endpoint.Live {
    static func translate(fromPersistance entity: Live, on db: Database) -> EventLoopFuture<Self> {
        let eventLoop = db.eventLoop
        guard let createdAt = entity.createdAt else {
            return eventLoop.makeFailedFuture(PersistanceError.cantTranslateEntityBeforeSaved)
        }
        let liveId = eventLoop.submit { try entity.requireID() }
        let performers = liveId.flatMap { liveId in
            LivePerformer.query(on: db)
                .filter(\.$live.$id == liveId)
                .with(\.$group).all()
        }
        .map { $0.map(\.group) }
        .flatMap { (groups: [Persistance.Group]) in
            eventLoop.flatten(
                groups.map {
                    Endpoint.Group.translate(fromPersistance: $0, on: db)
                })
        }
        let hostGroup = entity.$hostGroup.get(on: db).flatMap {
            Endpoint.Group.translate(fromPersistance: $0, on: db)
        }

        return hostGroup.and(performers).map { ($0, $1) }
            .flatMapThrowing { (hostGroup, performers) -> Endpoint.Live in
                let style: LiveStyleOutput
                switch entity.style {
                case .oneman:
                    style = .oneman(performer: hostGroup)
                case .battle:
                    style = .battle(performers: performers)
                case .festival:
                    style = .festival(performers: performers)
                }
                return try Self.init(
                    id: Endpoint.Live.ID(entity.requireID()),
                    title: entity.title,
                    style: style, price: entity.price,
                    artworkURL: entity.artworkURL.flatMap(URL.init(string:)),
                    hostGroup: hostGroup, liveHouse: entity.liveHouse,
                    date: entity.date, endDate: entity.endDate, openAt: entity.openAtV2,
                    startAt: entity.startAtV2,
                    piaEventCode: entity.piaEventCode,
                    piaReleaseUrl: entity.piaReleaseUrl.map { URL(string: $0)! },
                    piaEventUrl: entity.piaEventUrl.map { URL(string: $0)! },
                    createdAt: createdAt
                )
            }
    }
}

final class Ticket: Model {
    static let schema = "tickets"

    @ID(key: .id)
    var id: UUID?

    @Enum(key: "status")
    var status: Domain.Ticket.Status

    @Parent(key: "live_id")
    var live: Live

    @Parent(key: "user_id")
    var user: User

    init() {}

    init(id: UUID? = nil, status: Domain.Ticket.Status, liveId: UUID, userId: UUID) {
        self.id = id
        self.status = status
        self.$live.id = liveId
        self.$user.id = userId
    }
}

extension Domain.Ticket {
    typealias PersistanceEntity = Ticket

    static func translate(fromPersistance entity: Ticket, on db: Database) -> EventLoopFuture<
        Domain.Ticket
    > {
        let live = entity.$live.get(on: db).flatMap {
            Domain.Live.translate(fromPersistance: $0, on: db)
        }
        let user = entity.$user.get(on: db).flatMap {
            Domain.User.translate(fromPersistance: $0, on: db)
        }
        return live.and(user).flatMapThrowing { (live, user) -> Domain.Ticket in
            try Domain.Ticket(
                id: Domain.Ticket.ID(entity.requireID()), status: entity.status,
                live: live, user: user
            )
        }
    }
}

extension Domain.LiveFeed {
    static func translate(fromPersistance entity: Live, selfUser: Domain.User.ID, on db: Database)
        -> EventLoopFuture<Domain.LiveFeed>
    {
        let isLiked = LiveLike.query(on: db)
            .filter(\.$live.$id == entity.id!)
            .filter(\.$user.$id == selfUser.rawValue)
            .count().map { $0 > 0 }
        let likeCount = LiveLike.query(on: db)
            .filter(\.$live.$id == entity.id!)
            .count()
        let postCount = Post.query(on: db)
            .filter(\.$live.$id == entity.id!)
            .count()

        return Domain.Live.translate(fromPersistance: entity, on: db)
            .and(isLiked).and(likeCount).and(postCount).map { ( $0.0.0, $0.0.1, $0.1, $1) }
            .map {
                Domain.LiveFeed(
                    live: $0, isLiked: $1, hasTicket: false, likeCount: $2, participantCount: 0,
                    postCount: $3, participatingFriends: [])
            }
    }
}
