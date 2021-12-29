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
        message: String,
        isRealMoney: Bool,
        groupId: Domain.Group.ID? = nil,
        liveId: Domain.Live.ID? = nil
    ) {
        self.id = id
        self.tip = tip
        self.$user.id = userId.rawValue
        self.type = type
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
            type: type,
            message: entity.message ?? "応援しています！",
            isRealMoney: entity.isRealMoney ?? false,
            thrownAt: entity.thrownAt!
        )
    }
}
