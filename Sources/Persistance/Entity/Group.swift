import Domain
import Fluent
import Foundation

final class Group: Model {
    static let schema = "groups"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "english_name")
    var englishName: String?

    @Field(key: "biography")
    var biography: String?

    @Timestamp(key: "since", on: .none)
    var since: Date?

    @Field(key: "artwork_url")
    var artworkURL: URL?

    @Field(key: "hometown")
    var hometown: String?

    init() {}

    init(
        name: String, englishName: String?,
        biography: String?, since: Date?, artworkURL: URL?,
        hometown: String?
    ) {
        self.name = name
        self.englishName = englishName
        self.biography = biography
        self.since = since
        self.artworkURL = artworkURL
        self.hometown = hometown
    }
}

extension Domain.Group: EntityConvertible {
    typealias PersistanceEntity = Group

    init(fromPersistance entity: Group) throws {
        try self.init(
            id: entity.requireID(),
            name: entity.name, englishName: entity.englishName,
            biography: entity.biography, since: entity.since,
            artworkURL: entity.artworkURL, hometown: entity.hometown
        )
    }

    func asPersistance() -> Group {
        Group(name: name, englishName: englishName, biography: biography,
              since: since, artworkURL: artworkURL, hometown: hometown)
    }
}
