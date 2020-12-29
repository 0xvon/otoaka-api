public struct Artist: Codable, Equatable {
    public var part: String
    public init(part: String) {
        self.part = part
    }
}

public struct Fan: Codable, Equatable {
    public init() {}
}

public enum RoleProperties: Codable, Equatable {
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

public struct User: Codable, Identifiable, Equatable {
    public typealias ID = Identifier<Self>
    public var id: ID
    public var name: String
    public var biography: String?
    public var thumbnailURL: String?
    public var role: RoleProperties

    public init(
        id: ID, name: String, biography: String?, thumbnailURL: String?, role: RoleProperties
    ) {
        self.id = id
        self.name = name
        self.biography = biography
        self.thumbnailURL = thumbnailURL
        self.role = role
    }
}
