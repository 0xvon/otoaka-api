import Domain
import Fluent
import Foundation
//
//final class Artist: Model {
//    static let schema = "artists"
//
//    @ID(key: .id)
//    var id: UUID?
//
//    @Field(key: "name")
//    var name: String
//    
//    @Field(key: "biography")
//    var biography: String?
//    
//    @Field(key: "thumbnail_url")
//    var thumbnailURL: String?
//
//    @Field(key: "part")
//    var part: String
//
//    init() {}
//}
//
//
//extension Domain.Artist: EntityConvertible {
//    typealias PersistanceEntity = Artist
//
//    init(fromPersistance entity: Artist) throws {
//        try self.init(
//            id: entity.requireID(), name: entity.name,
//            biography: entity.biography,
//            thumbnailURL: entity.thumbnailURL,
//            part: entity.part
//        )
//    }
//
//    func asPersistance() -> Artist {
//        let artist = Artist()
//        artist.id = id
//        artist.name = name
//        artist.biography = biography
//        artist.thumbnailURL = thumbnailURL
//        artist.part = part
//
//        return artist
//    }
//}
//
