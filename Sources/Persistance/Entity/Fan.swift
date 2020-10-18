import Domain
import Fluent
import Foundation
//
//final class Fan: Model {
//    static let schema = "fans"
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
//    init() {}
//}
//
//extension Domain.Fan: EntityConvertible {
//    typealias PersistanceEntity = Fan
//
//    init(fromPersistance entity: Fan) throws {
//        try self.init(
//            id: entity.requireID(),
//            name: entity.name,
//            biography: entity.biography,
//            thumbnailURL: entity.thumbnailURL
//        )
//    }
//
//    func asPersistance() -> Fan {
//        let fan = Fan()
//        fan.id = id
//        fan.name = name
//        fan.biography = biography
//        fan.thumbnailURL = thumbnailURL
//        return fan
//    }
//}
