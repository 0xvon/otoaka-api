import CodableURL
import Foundation
import DomainEntity

// チップを送る
public struct SendSocialTip: EndpointProtocol {
    public struct Request: Codable {
        public var tip: Int
        public var type: SocialTipType
        
        public init(
            tip: Int, type: SocialTipType
        ) {
            self.tip = tip
            self.type = type
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

public struct GroupTip: Codable, Equatable {
    public var group: Group
    public var tip: Int
    
    public init(
        group: Group,
        tip: Int
    ) {
        self.group = group
        self.tip = tip
    }
}

public struct UserTip: Codable, Equatable {
    public var user: User
    public var tip: Int
    
    public init(
        user: User,
        tip: Int
    ) {
        self.user = user
        self.tip = tip
    }
}
