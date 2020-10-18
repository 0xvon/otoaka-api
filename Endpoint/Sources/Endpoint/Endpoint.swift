public enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

public protocol EndpointProtocol {
    associatedtype Request: Codable
    associatedtype Response: Codable
    associatedtype Parameters

    static var method: HTTPMethod { get }
    static var pathPattern: [String] { get }
    static func buildPath(with parameters: Parameters) -> [String]
}

public struct Empty: Codable {
    public init() {}
}

public enum Role: String, Codable {
    case artist
    case fan
}

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
    public static let method: HTTPMethod = .post
    public static let pathPattern = ["users", "signup"]
    public static func buildPath(with _: Void) -> [String] {
        pathPattern
    }
}

public struct GetUserInfo: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = User
    public static let method: HTTPMethod = .get
    public static let pathPattern = ["users", "get_info"]
    public static func buildPath(with _: Void) -> [String] {
        pathPattern
    }
}

public struct GetBand: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Empty
    public static let method: HTTPMethod = .get
    public typealias Parameters = Int

    public static let pathPattern = ["bands", ":band_id"]
    public static func buildPath(with bandId: Parameters) -> [String] {
        ["bands", bandId.description]
    }
}
