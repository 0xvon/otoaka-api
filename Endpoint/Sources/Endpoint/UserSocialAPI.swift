import Foundation

public struct FollowGroup: EndpointProtocol {
    public struct Request: Codable {
        public var id: Group.ID
        public init(groupId: Group.ID) {
            self.id = groupId
        }
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
        public init(groupId: Group.ID) {
            self.id = groupId
        }
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

public struct LiveFeed: Codable {
    public var live: Live
    public var isLiked: Bool
    public var hasTicket: Bool

    public init(live: Live, isLiked: Bool, hasTicket: Bool) {
        self.live = live
        self.isLiked = isLiked
        self.hasTicket = hasTicket
    }
}

public struct GetUpcomingLives: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<LiveFeed>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "upcoming_lives") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetFollowingGroupFeeds: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<ArtistFeed>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("user_social", "group_feeds") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct LikeLive: EndpointProtocol {
    public struct Request: Codable {
        public var liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "like_live") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct UnlikeLive: EndpointProtocol {
    public struct Request: Codable {
        public var liveId: Live.ID
        public init(liveId: Live.ID) {
            self.liveId = liveId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("user_social", "unlike_live") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct PostFeedComment: EndpointProtocol {
    public struct Request: Codable {
        public var feedId: ArtistFeed.ID
        public var text: String
        public init(feedId: ArtistFeed.ID, text: String) {
            self.feedId = feedId
            self.text = text
        }
    }
    public typealias Response = ArtistFeedComment
    public struct URI: CodableURL {
        @StaticPath("user_social", "feed_comment") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetFeedComments: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<ArtistFeedComment>
    public struct URI: CodableURL {
        @StaticPath("user_social", "feed_comment") public var prefix: Void
        @DynamicPath public var feedId: ArtistFeed.ID
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}
