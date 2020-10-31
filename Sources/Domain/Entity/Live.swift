import Foundation

public enum LiveStyle: String, Codable {
    case oneman
    case battle
    case festival
}

public struct Live {

    public typealias ID = Identifier<Self>
    public let id: ID

    public var title: String
    public var style: LiveStyle
    public var artworkURL: URL?
    public var hostGroup: Group
    public var author: User
    // TODO: liveHouseId
    public var openAt: Date?
    public var startAt: Date?
    public var endAt: Date?
    public var performers: [Group]

    public init(
        id: Live.ID, title: String,
        style: LiveStyle, artworkURL: URL?,
        author: User, hostGroup: Group,
        startAt: Date?, endAt: Date?,
        performers: [Group]
    ) {
        self.id = id
        self.title = title
        self.style = style
        self.artworkURL = artworkURL
        self.author = author
        self.hostGroup = hostGroup
        self.startAt = startAt
        self.endAt = endAt
        self.performers = performers
    }

}
