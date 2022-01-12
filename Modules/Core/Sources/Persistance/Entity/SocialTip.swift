import Domain
import FluentKit
import Foundation

enum SocialTipType: String, Codable {
    case group, live
}

final class SocialTip: Model {
    static var schema: String = "social_tips"
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "tip")
    var tip: Int
    
    @Parent(key: "user_id")
    var user: User
    
    @Enum(key: "type")
    var type: SocialTipType
    
    @OptionalField(key: "theme")
    var theme: String?
    
    @OptionalField(key: "message")
    var message: String?
    
    @OptionalField(key: "is_real_money")
    var isRealMoney: Bool?
    
    @OptionalParent(key: "group_id")
    var group: Group?
    
    @OptionalParent(key: "live_id")
    var live: Live?
    
    @Timestamp(key: "thrown_at", on: .create)
    var thrownAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil,
        tip: Int,
        userId: Domain.User.ID,
        type: SocialTipType,
        theme: String,
        message: String,
        isRealMoney: Bool,
        groupId: Domain.Group.ID? = nil,
        liveId: Domain.Live.ID? = nil
    ) {
        self.id = id
        self.tip = tip
        self.$user.id = userId.rawValue
        self.type = type
        self.theme = theme
        self.message = message
        self.isRealMoney = isRealMoney
        self.$group.id = groupId?.rawValue
        self.$live.id = liveId?.rawValue
    }
}

extension Endpoint.SocialTip {
    static func translate(fromPersistance entity: SocialTip, on db: Database) async throws -> Self {
        let user = try await Domain.User.translate(
            fromPersistance: entity.$user.get(on: db)
            , on: db
        ).get()
        let id = try entity.requireID()
        
        var type: Endpoint.SocialTipType
        switch entity.type {
        case .group:
            let group = try await Domain.Group.translate(
                fromPersistance: entity.$group.get(on: db)!,
                on: db
            ).get()
            type = .group(group)
        case .live:
            let live = try await Domain.Live.translate(
                fromPersistance: entity.$live.get(on: db)!,
                on: db
            ).get()
            type = .live(live)
        }
        
        return Self.init(
            id: ID(id),
            user: user,
            tip: entity.tip,
            theme: entity.theme ?? "このアーティストのオススメなところ",
            type: type,
            message: entity.message ?? "応援しています！",
            isRealMoney: entity.isRealMoney ?? false,
            thrownAt: entity.thrownAt!
        )
    }
}

final class SocialTipEvent: Model {
    static var schema: String = "social_tip_events"
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "live_id")
    var live: Live
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "description")
    var description: String
    
    @OptionalField(key: "related_link")
    var relatedLink: String?
    
    @Field(key: "since")
    var since: Date
    
    @Field(key: "until")
    var until: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(
        id: UUID? = nil,
        liveId: Domain.Live.ID,
        title: String,
        description: String,
        relatedLink: URL?,
        since: Date,
        until: Date
    ) {
        self.id = id
        self.$live.id = liveId.rawValue
        self.title = title
        self.description = description
        self.relatedLink = relatedLink?.absoluteString
        self.since = since
        self.until = until
    }
}

extension Endpoint.SocialTipEvent {
    static func translate(fromPersistance entity: SocialTipEvent, on db: Database) async throws -> Self {
        let id = try entity.requireID()
        let live = try await Domain.Live.translate(fromPersistance: entity.$live.get(on: db), on: db).get()
        
        return Self.init(
            id: ID(id),
            live: live,
            title: entity.title,
            description: entity.description,
            relatedLink: entity.relatedLink.flatMap(URL.init(string:)),
            since: entity.since,
            until: entity.until,
            createdAt: entity.createdAt!
        )
        
    }
}
