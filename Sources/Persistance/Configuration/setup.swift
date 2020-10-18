//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Fluent
import FluentMySQLDriver

// configures persistance system
public func setup(
    databases: Databases,
    migrator: Migrator,
    migrations: Migrations,
    environmentGetter: (String) -> String?
) throws {
    databases.use(.mysql(
        hostname: environmentGetter("DATABASE_HOST") ?? "localhost",
        username: environmentGetter("DATABASE_USERNAME") ?? "vapor_username",
        password: environmentGetter("DATABASE_PASSWORD") ?? "vapor_password",
        database: environmentGetter("DATABASE_NAME") ?? "vapor_database",
        tlsConfiguration: .forClient(certificateVerification: .none)
    ), as: .mysql)

    migrations.add(CreateUser())

    try migrator.setupIfNeeded().flatMap {
        migrator.prepareBatch()
    }.wait()
}
