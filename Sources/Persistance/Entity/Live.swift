import Domain
import Fluent
import Foundation

final class Live: Model {
    static let schema = "lives"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Enum(key: "style")
    var style: LiveStyle

    @OptionalField(key: "artwork_url")
    var artworkURL: URL?

    @Parent(key: "host_group_id")
    var hostGroup: Group
    
    @Parent(key: "author_id")
    var author: User
    
    // TODO: liveHouseId
    @Timestamp(key: "open_at", on: .none)
    var openAt: Date?
    @Timestamp(key: "start_at", on: .none)
    var startAt: Date?
    @Timestamp(key: "end_at", on: .none)
    var endAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        title: String, style: LiveStyle,
        artworkURL: URL?,
        hostGroupId: Domain.Group.ID,
        authorId: Domain.User.ID,
        openAt: Date?, startAt: Date?, endAt: Date?
    ) {
        self.id = nil
        self.title = title
        self.style = style
        self.artworkURL = artworkURL
        self.$hostGroup.id = hostGroupId.rawValue
        self.$author.id = authorId.rawValue
        self.openAt = openAt
        self.startAt = startAt
        self.endAt = endAt
    }
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


extension Domain.Live: EntityConvertible {
    typealias PersistanceEntity = Live
    
    static func translate(fromPersistance entity: Live, on db: Database) -> EventLoopFuture<Self> {
        let eventLoop = db.eventLoop
        let liveId = eventLoop.submit { try entity.requireID() }
        let performers = liveId.flatMap { liveId in
            LivePerformer.query(on: db)
                .filter(\.$live.$id == liveId)
                .with(\.$group).all()
        }
        .map { $0.map(\.group) }
        .flatMap { (groups: [Persistance.Group]) in
            eventLoop.flatten(groups.map {
                Domain.Group.translate(fromPersistance: $0, on: db)
            })
        }
        let hostGroup = entity.$hostGroup.get(on: db).flatMap {
            Domain.Group.translate(fromPersistance: $0, on: db)
        }
        let author = entity.$author.get(on: db).flatMap {
            Domain.User.translate(fromPersistance: $0, on: db)
        }
        
        return hostGroup.and(performers).and(author).map { ($0.0, $0.1, $1) }
            .flatMapThrowing { (hostGroup, performers, author) -> Domain.Live in
                try Self.init(
                    id: Domain.Live.ID(entity.requireID()),
                    title: entity.title,
                    style: entity.style,
                    artworkURL: entity.artworkURL,
                    author: author,
                    hostGroup: hostGroup,
                    startAt: entity.startAt, endAt: entity.endAt,
                    performers: performers
                )
            }
    }
    
    func asPersistance() -> Live {
        Live(id: id.rawValue,
             title: title, style: style, artworkURL: artworkURL,
             hostGroupId: hostGroup.id, authorId: author.id, openAt: openAt,
             startAt: startAt, endAt: endAt
        )
    }
}
