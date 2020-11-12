import CodableURL

public struct Artist: Codable {
    public var part: String
    public init(part: String) {
        self.part = part
    }
}

public struct Fan: Codable {
    public init() {}
}

public enum RoleProperties: Codable {
    case artist(Artist)
    case fan(Fan)

    enum CodingKeys: CodingKey {
        case kind, value
    }

    enum Kind: String, Codable {
        case artist, fan
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .artist:
            self = try .artist(container.decode(Artist.self, forKey: .value))
        case .fan:
            self = try .fan(container.decode(Fan.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .artist(artist):
            try container.encode(Kind.artist, forKey: .kind)
            try container.encode(artist, forKey: .value)
        case let .fan(fan):
            try container.encode(Kind.fan, forKey: .kind)
            try container.encode(fan, forKey: .value)
        }
    }
}

public struct User: Codable {
    public var id: String
    public var name: String
    public var biography: String?
    public var thumbnailURL: String?
    public var role: RoleProperties

    public init(id: String, name: String, biography: String?, thumbnailURL: String?, role: RoleProperties) {
        self.id = id
        self.name = name
        self.biography = biography
        self.thumbnailURL = thumbnailURL
        self.role = role
    }
}

public struct Signup: EndpointProtocol {
    public struct Request: Codable {
        public init(name: String, biography: String? = nil, thumbnailURL: String? = nil, role: RoleProperties) {
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
    public struct URL: CodableURL {
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
    public struct URL: CodableURL {
        @StaticPath("users", "get_signup_status") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct GetUserInfo: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = User
    public struct URL: CodableURL {
        @StaticPath("users", "get_info") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .get
}
