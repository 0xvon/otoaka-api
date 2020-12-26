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
