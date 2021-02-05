import Foundation

public struct CreateGroup: EndpointProtocol {
    public struct Request: Codable {
        public var name: String
        public var englishName: String?
        public var biography: String?
        public var since: Date?
        public var artworkURL: Foundation.URL?
        public var twitterId: String?
        public var youtubeChannelId: String?
        public var hometown: String?

        public init(
            name: String, englishName: String?, biography: String?,
            since: Date?, artworkURL: Foundation.URL?,
            twitterId: String?, youtubeChannelId: String?, hometown: String?
        ) {
            self.name = name
            self.englishName = englishName
            self.biography = biography
            self.since = since
            self.artworkURL = artworkURL
            self.twitterId = twitterId
            self.youtubeChannelId = youtubeChannelId
            self.hometown = hometown
        }
    }

    public typealias Response = Group
    public struct URI: CodableURL {
        @StaticPath("groups") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct EditGroup: EndpointProtocol {
    public typealias Request = CreateGroup.Request
    public typealias Response = Group
    public struct URI: CodableURL {
        @StaticPath("groups", "edit") public var prefix: Void
        @DynamicPath public var id: Group.ID
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct DeleteGroup: EndpointProtocol {
    public struct Request: Codable {
        public let id: Group.ID

        public init(id: Group.ID) {
            self.id = id
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("groups", "delete") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .delete
}

public struct InviteGroup: EndpointProtocol {
    public struct Request: Codable {
        public var groupId: Group.ID
        public init(groupId: Group.ID) {
            self.groupId = groupId
        }
    }

    public struct Invitation: Codable {
        public var id: String

        public init(id: String) {
            self.id = id
        }
    }

    public typealias Response = Invitation
    public struct URI: CodableURL {
        @StaticPath("groups", "invite") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct JoinGroup: EndpointProtocol {
    public struct Request: Codable {
        public var invitationId: String

        public init(invitationId: String) {
            self.invitationId = invitationId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("groups", "join") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct GetGroup: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable {
        public init(group: Group, isMember: Bool, isFollowing: Bool, followersCount: Int) {
            self.group = group
            self.isMember = isMember
            self.isFollowing = isFollowing
            self.followersCount = followersCount
        }

        public var group: Group
        public var isMember: Bool
        public var isFollowing: Bool
        public var followersCount: Int
    }
    public struct URI: CodableURL {
        @StaticPath("groups") public var prefix: Void
        @DynamicPath public var groupId: Group.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetMemberships: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = [Group]
    public struct URI: CodableURL {
        @StaticPath("groups", "memberships") public var prefix: Void
        @DynamicPath public var artistId: User.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetAllGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Group>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("groups") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetGroupLives: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Live>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("groups") public var prefix: Void
        @DynamicPath public var groupId: Group.ID
        @StaticPath("lives") public var suffix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct CreateArtistFeed: EndpointProtocol {
    public struct Request: Codable {
        public var text: String
        public var feedType: FeedType
        public init(text: String, feedType: FeedType) {
            self.text = text
            self.feedType = feedType
        }
    }

    public typealias Response = ArtistFeed
    public struct URI: CodableURL {
        @StaticPath("groups", "create_feed") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct DeleteArtistFeed: EndpointProtocol {
    public struct Request: Codable {
        public let id: ArtistFeed.ID

        public init(id: ArtistFeed.ID) {
            self.id = id
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("groups", "delete_feed") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .delete
}

public struct GetGroupFeed: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<ArtistFeedSummary>

    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("groups") public var prefix: Void
        @DynamicPath public var groupId: Group.ID
        @StaticPath("feeds") public var suffix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct SearchGroup: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<Group>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("groups", "search") public var prefix: Void
        @Query public var term: String
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}
