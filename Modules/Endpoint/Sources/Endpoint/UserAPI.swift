import CodableURL
import Foundation

public struct Signup: EndpointProtocol {
    public struct Request: Codable {
        public init(
            name: String, biography: String? = nil, sex: String?, age: Int?, liveStyle: String?, residence: String?, thumbnailURL: String? = nil,
            role: RoleProperties, twitterUrl: URL?, instagramUrl: URL?
        ) {
            self.name = name
            self.biography = biography
            self.sex = sex
            self.age = age
            self.liveStyle = liveStyle
            self.residence = residence
            self.thumbnailURL = thumbnailURL
            self.role = role
            self.twitterUrl = twitterUrl
            self.instagramUrl = instagramUrl
        }

        public var name: String
        public var biography: String?
        public var sex: String?
        public var age: Int?
        public var liveStyle: String?
        public var residence: String?
        public var thumbnailURL: String?
        public var role: RoleProperties
        public var twitterUrl: URL?
        public var instagramUrl: URL?
    }

    public typealias Response = User
    public struct URI: CodableURL {
        @StaticPath("users", "signup") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct EditUserInfo: EndpointProtocol {
    public typealias Request = Signup.Request

    public typealias Response = User
    public struct URI: CodableURL {
        @StaticPath("users", "edit_user_info") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct SignupStatus: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable {
        public var isSignedup: Bool
        public init(isSignedup: Bool) {
            self.isSignedup = isSignedup
        }
    }
    public struct URI: CodableURL {
        @StaticPath("users", "get_signup_status") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetUserInfo: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = User
    public struct URI: CodableURL {
        @StaticPath("users", "get_info") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetUserDetail: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = UserDetail
    public struct URI: CodableURL {
        @StaticPath("users") public var prefix: Void
        @DynamicPath public var userId: User.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

@dynamicMemberLookup
public struct UserDetail: Codable, Equatable {
    public var user: User
    public var followersCount: Int
    public var followingUsersCount: Int
    public var feedCount: Int
    public var likeFeedCount: Int
    public var postCount: Int
    public var likePostCount: Int
    public var followingGroupsCount: Int
    public var isFollowed: Bool
    public var isFollowing: Bool
    public var isBlocked: Bool
    public var isBlocking: Bool

    public subscript<T>(dynamicMember keyPath: KeyPath<User, T>) -> T {
        user[keyPath: keyPath]
    }

    public init(user: User, followersCount: Int, followingUsersCount: Int, feedCount: Int, likeFeedCount: Int, postCount: Int, likePostCount: Int, followingGroupsCount: Int, isFollowed: Bool, isFollowing: Bool, isBlocked: Bool, isBlocking: Bool) {
        self.user = user
        self.followersCount = followersCount
        self.followingUsersCount = followingUsersCount
        self.feedCount = feedCount
        self.likeFeedCount = likeFeedCount
        self.postCount = postCount
        self.likePostCount = likePostCount
        self.followingGroupsCount = followingGroupsCount
        self.isFollowed = isFollowed
        self.isFollowing = isFollowing
        self.isBlocked = isBlocked
        self.isBlocking = isBlocking
    }
}

public struct RegisterDeviceToken: EndpointProtocol {
    public struct Request: Codable {
        public var deviceToken: String
        public init(deviceToken: String) {
            self.deviceToken = deviceToken
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("users", "register_device_token") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct CreateUserFeed: EndpointProtocol {
    public struct Request: Codable {
        public var text: String
        public var feedType: FeedType
        public var ogpUrl: String?
        public var thumbnailUrl: String?
        public var groupId: Group.ID
        public var title: String
        
        public init(
            text: String, feedType: FeedType, ogpUrl: String?, thumbnailUrl: String?, groupId: Group.ID, title: String
        ) {
            self.text = text
            self.feedType = feedType
            self.ogpUrl = ogpUrl
            self.thumbnailUrl = thumbnailUrl
            self.groupId = groupId
            self.title = title
        }
    }

    public typealias Response = UserFeed
    public struct URI: CodableURL {
        @StaticPath("users", "create_feed") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct DeleteUserFeed: EndpointProtocol {
    public struct Request: Codable {
        public let id: UserFeed.ID

        public init(id: UserFeed.ID) {
            self.id = id
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("users", "delete_feed") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .delete
}

public struct GetUserFeeds: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<UserFeedSummary>

    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("users") public var prefix: Void
        @DynamicPath public var userId: User.ID
        @StaticPath("feeds") public var suffix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetUserFeed: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = UserFeedSummary
    public struct URI: CodableURL {
        @StaticPath("users", "feeds") public var prefix: Void
        @DynamicPath public var feedId: UserFeed.ID
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct Track: Codable {
    public var name: String
    public var artistName: String
    public var artwork: String
    public var trackType: FeedType
    
    public init(
        name: String, artistName: String, artwork: String, trackType: FeedType
    ) {
        self.name = name
        self.artistName = artistName
        self.artwork = artwork
        self.trackType = trackType
    }
}

public struct CreatePost: EndpointProtocol {
    public struct Request: Codable {
        public var author: User
        public var live: Live
        public var text: String
        public var tracks: [Track]
        public var groups: [Group]
        public var imageUrls: [String]
        
        public init(
            author: User,
            live: Live,
            text: String,
            tracks: [Track],
            groups: [Group],
            imageUrls: [String]
        ) {
            self.author = author
            self.live = live
            self.text = text
            self.tracks = tracks
            self.groups = groups
            self.imageUrls = imageUrls
        }
    }
    
    public typealias Response = Post
    public struct URI: CodableURL {
        @StaticPath("users", "create_post") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct EditPost: EndpointProtocol {
    public typealias Request = CreatePost.Request
    public typealias Response = Post
    public struct URI: CodableURL {
        @StaticPath("users", "edit_post") public var prefix: Void
        @DynamicPath public var id: Post.ID
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct DeletePost: EndpointProtocol {
    public struct Request: Codable {
        public let postId: Post.ID
        
        public init(postId: Post.ID) {
            self.postId = postId
        }
    }
    
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("users", "delete_post") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .delete
}

public struct GetPosts: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<PostSummary>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("users") public var prefix: Void
        @DynamicPath public var userId: User.ID
        @StaticPath("posts") public var suffix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct SearchUser: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<User>
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("users", "search") public var prefix: Void
        @Query public var term: String
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetNotifications: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Page<UserNotification>
    
    public struct URI: CodableURL, PaginationQuery {
        @StaticPath("users", "notifications") public var prefix: Void
        @Query public var page: Int
        @Query public var per: Int
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct ReadNotification: EndpointProtocol {
    public struct Request: Codable {
        public var notificationId: UserNotification.ID
        public init(notificationId: UserNotification.ID) {
            self.notificationId = notificationId
        }
    }
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("users", "read_notification") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}
