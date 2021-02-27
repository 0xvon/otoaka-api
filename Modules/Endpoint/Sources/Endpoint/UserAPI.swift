import CodableURL

public struct Signup: EndpointProtocol {
    public struct Request: Codable {
        public init(
            name: String, biography: String? = nil, thumbnailURL: String? = nil,
            role: RoleProperties
        ) {
            self.name = name
            self.biography = biography
            self.thumbnailURL = thumbnailURL
            self.role = role
        }

        public var name: String
        public var biography: String?
        public var thumbnailURL: String?
        public var role: RoleProperties
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
        public init(text: String, feedType: FeedType) {
            self.text = text
            self.feedType = feedType
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
