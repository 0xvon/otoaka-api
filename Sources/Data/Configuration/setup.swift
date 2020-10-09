//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Fluent
import FluentMySQLDriver
import Vapor

// configures your application
public func setup(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.mysql(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tlsConfiguration: .forClient(certificateVerification: .none)
    ), as: .mysql)
    
    app.migrations.add(CreateFan())
//    try app.autoMigrate().wait()
}

