//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Fluent

struct CreateFan: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("fans")
            .id()
            .field("display_name", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("fans").delete()
    }
}
