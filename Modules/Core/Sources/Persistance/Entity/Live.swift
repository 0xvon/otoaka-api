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

    @Parent(key: "author_id")
    var author: User

    @OptionalField(key: "live_house")
    var liveHouse: String?

    @Timestamp(key: "open_at", on: .none)
    var openAt: Date?
    @Timestamp(key: "start_at", on: .none)
    var startAt: Date?
    @Timestamp(key: "end_at", on: .none)
    var endAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        title: String, style: LiveStyle,
        price: Int, artworkURL: URL?,
        hostGroupId: Domain.Group.ID,
        authorId: Domain.User.ID, liveHouse: String?,
        openAt: Date?, startAt: Date?, endAt: Date?
    ) {
        self.id = nil
        self.title = title
        self.style = style
        self.price = price
        self.artworkURL = artworkURL?.absoluteString
        self.$hostGroup.id = hostGroupId.rawValue
        self.$author.id = authorId.rawValue
        self.liveHouse = liveHouse
        self.openAt = openAt
        self.startAt = startAt
        self.endAt = endAt
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
        let author = entity.$author.get(on: db).flatMap {
            Endpoint.User.translate(fromPersistance: $0, on: db)
        }

        return hostGroup.and(performers).and(author).map { ($0.0, $0.1, $1) }
            .flatMapThrowing { (hostGroup, performers, author) -> Endpoint.Live in
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
                    author: author,
                    hostGroup: hostGroup, liveHouse: entity.liveHouse,
                    startAt: entity.startAt, endAt: entity.endAt, createdAt: createdAt
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