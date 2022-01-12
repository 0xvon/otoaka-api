import Foundation

public struct SocialTip: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public let id: ID
    public var user: User
    public var tip: Int
    public var theme: String
    public var type: SocialTipType
    public var message: String
    public var isRealMoney: Bool
    public var thrownAt: Date
    
    public init(
        id: SocialTip.ID,
        user: User,
        tip: Int,
        theme: String,
        type: SocialTipType,
        message: String,
        isRealMoney: Bool,
        thrownAt: Date
    ) {
        self.id = id
        self.user = user
        self.tip = tip
        self.theme = theme
        self.type = type
        self.message = message
        self.isRealMoney = isRealMoney
        self.thrownAt = thrownAt
    }
}

public enum SocialTipType: Codable, Equatable {
    case group(Group)
    case live(Live)
    
    enum CodingKeys: CodingKey {
        case kind, value
    }
    
    enum Kind: String, Codable {
        case group, live
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .group:
            self = try .group(container.decode(Group.self, forKey: .value))
        case .live:
            self = try .live(container.decode(Live.self, forKey: .value))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .group(group):
            try container.encode(Kind.group, forKey: .kind)
            try container.encode(group, forKey: .value)
        case let .live(live):
            try container.encode(Kind.live, forKey: .kind)
            try container.encode(live, forKey: .value)
        }
    }
}

public struct SocialTipEvent: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public let id: ID
    public var live: Live
    public var title: String
    public var description: String
    public var relatedLink: URL?
    public var since: Date
    public var until: Date
    public var createdAt: Date
    
    public init(
        id: SocialTipEvent.ID,
        live: Live,
        title: String,
        description: String,
        relatedLink: URL?,
        since: Date,
        until: Date,
        createdAt: Date
    ) {
        self.id = id
        self.live = live
        self.title = title
        self.description = description
        self.relatedLink = relatedLink
        self.since = since
        self.until = until
        self.createdAt = createdAt
    }
}
