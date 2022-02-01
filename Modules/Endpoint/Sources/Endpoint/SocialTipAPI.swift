import CodableURL
import Foundation
import DomainEntity

// チップを送る
public struct SendSocialTip: EndpointProtocol {
    public struct Request: Codable {
        public var tip: Int
        public var type: SocialTipType
        public var theme: String
        public var message: String
        public var isRealMoney: Bool
        
        public init(
            tip: Int, type: SocialTipType, theme: String, message: String, isRealMoney: Bool
        ) {
            self.tip = tip
            self.type = type
            self.theme = theme
            self.message = message
            self.isRealMoney = isRealMoney
        }
    }
    
    public typealias Response = SocialTip
    public struct URI: CodableURL {
        @StaticPath("social_tips", "send") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

// すべてのチップ
public struct GetAllTips: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<SocialTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "all") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

// 高額チップ
public struct GetHighTips: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<SocialTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "high") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

// groupごとのチップ
public struct GetGroupTips: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<SocialTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "groups") public var prefix: Void
        @DynamicPath public var groupId: Group.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

// userごとのチップ
public struct GetUserTips: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<SocialTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "users") public var prefix: Void
        @DynamicPath public var userId: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

// 任意のuserのgroupごとのチップランキング
public struct GetUserTipToGroupRanking: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<GroupTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "user_ranking") public var prefix: Void
        @DynamicPath public var userId: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

// groupごとのチップランキング
public struct GetGroupTipFromUserRanking: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<UserTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "group_ranking") public var prefix: Void
        @DynamicPath public var groupId: Group.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct GetUserTipFeed: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response =  Page<UserTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "user_tip_feed") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct GetSocialTippableGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = [Group]
    
    public struct URI: CodableURL {
        @StaticPath("social_tips", "social_tippable_groups") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

// social tipランキング
public struct GetEntriedGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<GroupTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "entried_groups") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct GetDailyGroupRanking: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<GroupTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "daily_group_ranking") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct GetWeeklyGroupRanking: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<GroupTip>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "weekly_group_ranking") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct GetSocialTipEvent: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<SocialTipEvent>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("social_tips", "events") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct CreateSocialTipEvent: EndpointProtocol {
    public struct Request: Codable {
        public var liveId: Live.ID
        public var title: String
        public var description: String
        public var relatedLink: URL?
        public var since: Date
        public var until: Date
        
        public init(
            liveId: Live.ID, title: String,
            description: String, relatedLink: URL?,
            since: Date, until: Date
        ) {
            self.liveId = liveId
            self.title = title
            self.description = description
            self.relatedLink = relatedLink
            self.since = since
            self.until = until
        }
    }
    public typealias Response = SocialTipEvent
    
    public struct URI: CodableURL {
        @StaticPath("social_tips", "events", "create") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}

public struct GroupTip: Codable, Equatable {
    public var group: Group
    public var tip: Int
    public var from: Date
    
    public init(
        group: Group,
        tip: Int,
        from: Date
    ) {
        self.group = group
        self.tip = tip
        self.from = from
    }
}

public struct UserTip: Codable, Equatable {
    public var user: User
    public var tip: Int
    public var from: Date
    
    public init(
        user: User,
        tip: Int,
        from: Date
    ) {
        self.user = user
        self.tip = tip
        self.from = from
    }
}
