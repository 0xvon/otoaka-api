import Foundation

public struct FollowGroup: EndpointProtocol {
    public struct Request: Codable {
        public var id: Group.ID
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "follow_group") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnfollowGroup: EndpointProtocol {
    public struct Request: Codable {
        public var id: Group.ID
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unfollow_group") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GroupFollowers: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<User>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "group_followers") public var prefix: Void
        @DynamicPath public var id: Group.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct FollowingGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Group>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "following_groups") public var prefix: Void
        @DynamicPath public var id: User.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}
