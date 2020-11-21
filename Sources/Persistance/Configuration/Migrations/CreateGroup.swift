import Fluent

struct CreateGroup: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Group.schema)
            .id()
            .field("name", .string, .required)
            .field("english_name", .string)
            .field("biography", .string)
            .field("since", .date)
            .field("artwork_url", .string)
            .field("hometown", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Group.schema).delete()
    }
}

struct CreateMembership: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Membership.schema)
            .id()
            .field("group_id", .uuid, .required)
            .foreignKey("group_id", references: Group.schema, "id")
            .field("artist_id", .uuid, .required)
            .foreignKey("artist_id", references: User.schema, "id")
            .field("is_leader", .bool, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Membership.schema).delete()
    }
}

struct CreateGroupInvitation: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(GroupInvitation.schema)
            .id()
            .field("group_id", .uuid, .required)
            .foreignKey("group_id", references: Group.schema, "id")
            .field("invited", .bool, .required)
            .field("membership_id", .uuid)
            .foreignKey("membership_id", references: Membership.schema, "id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(GroupInvitation.schema).delete()
    }
}
