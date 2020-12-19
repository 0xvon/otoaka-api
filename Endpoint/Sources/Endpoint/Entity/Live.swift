import Foundation

public enum LiveStyle<Performer>: Codable where Performer: Codable {
    case oneman(performer: Performer)
    case battle(performers: [Performer])
    case festival(performers: [Performer])

    enum CodingKeys: CodingKey {
        case kind, value
    }

    enum Kind: String, Codable {
        case oneman, battle, festival
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .oneman:
            self = try .oneman(performer: container.decode(Performer.self, forKey: .value))
        case .battle:
            self = try .battle(performers: container.decode([Performer].self, forKey: .value))
        case .festival:
            self = try .festival(performers: container.decode([Performer].self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .oneman(performer):
            try container.encode(Kind.oneman, forKey: .kind)
            try container.encode(performer, forKey: .value)
        case let .battle(performers):
            try container.encode(Kind.battle, forKey: .kind)
            try container.encode(performers, forKey: .value)
        case let .festival(performers):
            try container.encode(Kind.festival, forKey: .kind)
            try container.encode(performers, forKey: .value)
        }
    }

    public var performers: [Performer] {
        switch self {
        case .oneman(let performer):
            return [performer]
        case .battle(let performers):
            return performers
        case .festival(let performers):
            return performers
        }
    }
}

public typealias LiveStyleInput = LiveStyle<Group.ID>
public typealias LiveStyleOutput = LiveStyle<Group>

public struct Live: Codable, Identifiable {

    public typealias ID = Identifier<Self>
    public let id: ID

    public var title: String
    public var style: LiveStyleOutput
    public var artworkURL: URL?
    public var hostGroup: Group
    public var author: User
    public var liveHouse: String?
    public var openAt: Date?
    public var startAt: Date?
    public var endAt: Date?
    public var createdAt: Date

    public init(
        id: ID, title: String,
        style: LiveStyleOutput, artworkURL: URL?,
        author: User, hostGroup: Group, liveHouse: String?,
        startAt: Date?, endAt: Date?, createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.style = style
        self.artworkURL = artworkURL
        self.author = author
        self.hostGroup = hostGroup
        self.liveHouse = liveHouse
        self.startAt = startAt
        self.endAt = endAt
        self.createdAt = createdAt
    }
}

public struct PerformanceRequest: Codable, Identifiable {
    public typealias ID = Identifier<Self>

    public enum Status: String, Codable {
        case accepted, denied, pending
    }

    public var id: ID
    public var status: Status
    public var live: Live
    public var group: Group

    public init(
        id: PerformanceRequest.ID, status: PerformanceRequest.Status, live: Live, group: Group
    ) {
        self.id = id
        self.status = status
        self.live = live
        self.group = group
    }
}

public struct Ticket: Codable {
    public typealias ID = Identifier<Self>

    public enum Status: String, Codable {
        case registered, paid, joined
    }

    public var id: ID
    public var status: Status
    public var live: Live
    public var user: User

    public init(id: Ticket.ID, status: Status, live: Live, user: User) {
        self.id = id
        self.status = status
        self.live = live
        self.user = user
    }
}
