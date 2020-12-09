import Domain
import Fluent
import Foundation

public enum Role: String, Codable {
    case artist
    case fan
}

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

    /// Only for artist.
    @OptionalField(key: "part")
    var part: String?

    init() {}
    init(
        cognitoId: Domain.CognitoID, email: String, name: String,
        biography: String?, thumbnailURL: String?, role: Domain.RoleProperties
    ) {
        self.cognitoId = cognitoId
        self.email = email
        self.name = name
        self.biography = biography
        self.thumbnailURL = thumbnailURL
        switch role {
        case .artist(let artist):
            self.role = .artist
            part = artist.part
        case .fan:
            self.role = .fan
        }
    }
}

extension Endpoint.User {
    static func translate(fromPersistance entity: User, on db: Database) -> EventLoopFuture<Self> {
        let roleProperties: Endpoint.RoleProperties
        switch entity.role {
        case .artist:
            roleProperties = .artist(Endpoint.Artist(part: entity.part!))
        case .fan:
            roleProperties = .fan(Endpoint.Fan())
        }
        return db.eventLoop.submit {
            try Self.init(
                id: ID(entity.requireID()), name: entity.name, biography: entity.biography,
                thumbnailURL: entity.thumbnailURL, role: roleProperties)
        }
    }
}

final class UserDevice: Model {
    static let schema = "user_devices"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "endpoint_arn")
    var endpointArn: String

    @Parent(key: "user_id")
    var user: User

    init() {}
    init(id: UUID? = nil, endpointArn: String, user: User.IDValue) {
        self.id = id
        self.endpointArn = endpointArn
        self.$user.id = user
    }
}

final class Following: Model {
    static let schema = "followings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "self_user_id")
    var user: User

    @Parent(key: "target_group_id")
    var target: Group

    init() {}
}

final class LiveLike: Model {
    static let schema = "live_likes"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "live_id")
    var live: Live
}
