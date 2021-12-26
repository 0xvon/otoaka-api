import Domain
import FluentKit
import Foundation

struct CreateLive: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let styleEnum = database.enum("live_style")
            .case("oneman")
            .case("battle")
            .case("festival")
            .create()

        return styleEnum.flatMap { styleEnum in
            return database.schema(Live.schema)
                .id()
                .field("title", .string, .required)
                .field("style", styleEnum, .required)
                .field("artwork_url", .string)
                .field("price", .int64, .required)
                .field("host_group_id", .uuid)
                .foreignKey("host_group_id", references: Group.schema, .id)
                .field("author_id", .uuid)
                .foreignKey("author_id", references: User.schema, .id)
                .field("live_house", .string)
                .field("open_at", .datetime)
                .field("start_at", .datetime)
                .field("end_at", .datetime)
                .field("created_at", .datetime, .required)
                .create()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Live.schema).delete()
            .and(database.enum("live_style").delete())
            .map { _ in }
    }
}

struct CreatePerformanceRequest: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let statusEnum = database.enum("performance_request_status")
            .case("accepted")
            .case("denied")
            .case("pending")
            .create()
        return statusEnum.flatMap { statusEnum in
            return database.schema(PerformanceRequest.schema)
                .id()
                .field("live_id", .uuid, .required)
                .field("group_id", .uuid, .required)
                .field("status", statusEnum, .required)
                .unique(on: "live_id", "group_id")
                .create()
        }
    }
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(PerformanceRequest.schema).delete()
    }
}

struct CreateLivePerformer: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(LivePerformer.schema)
            .id()
            .field("live_id", .uuid, .required)
            .field("group_id", .uuid, .required)
            .unique(on: "live_id", "group_id")
            .create()
    }
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(LivePerformer.schema).delete()
    }
}

struct CreateTicket: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let statusEnum = database.enum("ticket_status")
            .case("reserved")
            .case("refunded")
            .create()

        return statusEnum.flatMap { statusEnum in
            database.schema(Ticket.schema)
                .id()
                .field("status", statusEnum, .required)
                .field("live_id", .uuid, .required)
                .foreignKey("live_id", references: Live.schema, .id)
                .field("user_id", .uuid, .required)
                .foreignKey("user_id", references: User.schema, .id)
                .create()
        }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Ticket.schema).delete()
            .and(database.enum("ticket_status").delete())
            .map { _ in }
    }
}

struct UpdateLiveForPia: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Live.schema)
            .field("date", .string)
            .field("open_at_v2", .string)
            .field("start_at_v2", .string)
            .field("pia_event_code", .string)
            .field("pia_release_url", .string)
            .field("pia_event_url", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Live.schema)
            .deleteField("date")
            .deleteField("open_at_v2")
            .deleteField("start_at_v2")
            .deleteField("pia_event_code")
            .deleteField("pia_release_url")
            .deleteField("pia_event_url")
            .update()
    }
}

struct UpdateLiveForDateTerm: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Live.schema)
            .field("end_date", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Live.schema)
            .deleteField("end_date")
            .update()
    }
}
