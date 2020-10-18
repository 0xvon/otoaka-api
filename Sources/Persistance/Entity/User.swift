import Domain
import Fluent
import Foundation
import Endpoint

final class User: Model {
    static var schema: String = "users"
    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "biography")
    var biography: String?

    @Field(key: "thumbnail_url")
    var thumbnailURL: String?

    @Field(key: "cognito_id")
    var cognitoId: String

    @Field(key: "email")
    var email: String

    @Enum(key: "role")
    var role: Role

    /// Only for artist
    @Field(key: "part")
    var part: String?

    init() {}
    init(cognitoId: Domain.User.CognitoID, email: String, name: String,
         biography: String?, thumbnailURL: String?, role: Domain.RoleProperties) {
        self.cognitoId = cognitoId
        self.email = email
        self.name = name
        self.biography = biography
        self.thumbnailURL = thumbnailURL
        switch role {
        case let .artist(artist):
            self.role = .artist
            self.part = artist.part
        case .fan:
            self.role = .fan
        }
    }
}

extension Domain.User: EntityConvertible {
    typealias PersistanceEntity = User

    init(fromPersistance entity: User) throws {
        let roleProperties: Domain.RoleProperties
        switch entity.role {
        case .artist:
            roleProperties = .artist(Artist(part: entity.part!))
        case .fan:
            roleProperties = .fan
        }
        try self.init(
            id: entity.requireID(), cognitoId: entity.cognitoId,
            email: entity.email, name: entity.name,
            biography: entity.biography, thumbnailURL: entity.thumbnailURL,
            role: roleProperties
        )
    }

    func asPersistance() -> User {
        let user = User()
        user.id = id
        user.cognitoId = cognitoId
        user.email = email
        user.biography = biography
        user.thumbnailURL = thumbnailURL
        switch role {
        case let .artist(artist):
            user.role = .artist
            user.part = artist.part
        case .fan:
            user.role = .fan
        }
        return user
    }
}
