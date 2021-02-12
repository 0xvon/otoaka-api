import FluentKit

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("cognito_id", .string, .required)
            .unique(on: "cognito_id")

            .field("biography", .string)
            .field("thumbnail_url", .string)

            .field(
                "role",
                .enum(
                    DatabaseSchema.DataType.Enum(name: "role", cases: ["artist", "fan"])
                )
            )
            .field("part", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema).delete()
    }
}

struct CreateFollowing: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Following.schema)
            .id()
            .field("self_user_id", .uuid, .required)
            .foreignKey("self_user_id", references: User.schema, .id)
            .field("target_group_id", .uuid, .required)
            .foreignKey("target_group_id", references: Group.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Following.schema).delete()
    }
}

struct CreateUserDevice: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserDevice.schema)
            .id()
            .field("endpoint_arn", .string, .required)
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .unique(on: "endpoint_arn", "user_id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserDevice.schema).delete()
    }
}

struct CreateLiveLike: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(LiveLike.schema)
            .id()
            .field("user_id", .uuid, .required)
            .foreignKey("user_id", references: User.schema, .id)
            .field("live_id", .uuid, .required)
            .foreignKey("live_id", references: Live.schema, .id)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(LiveLike.schema).delete()
    }
}

public protocol PersistanceUser: AnyObject {
    var cognitoId: String { get }
    var cognitoUsername: String? { get set }
}

extension User: PersistanceUser {}

struct CognitoSubToUsername: Migration {
    let migrator: (_ users: [PersistanceUser]) -> EventLoopFuture<Void>

    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let addColumn = database.schema(User.schema)
            .field("cognito_username", .string)
            .unique(on: "cognito_username")
            .update()

        return addColumn.flatMap {
            User.query(on: database)
                .filter(\.$cognitoUsername == nil)
                .all()
                .flatMap { migrator($0) }
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(User.schema)
            .deleteField("cognito_username")
            .update()
    }
}
