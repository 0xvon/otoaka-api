//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Domain
import Foundation
import Persistance
import Vapor

private func injectProvider<T>(_ handler: @escaping (Request, FanProvider) throws -> T) -> ((Request) throws -> T) {
    return { req in
        let fanRepository = Persistance.FanRepository(db: req.db)
        let provider = FanProvider(fanRepository)
        return try handler(req, provider)
    }
}

struct FanController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let fans = routes.grouped("fans")
        fans.post(use: injectProvider(createFan))
        fans.get(use: injectProvider(listFans))
    }

    func createFan(req: Request, provider: FanProvider) throws -> EventLoopFuture<Domain.Fan> {
        let fan = try req.content.decode(Domain.CreateFanInput.self)
        return try provider.createFanUseCase(fan)
    }

    func listFans(req _: Request, provider: FanProvider) throws -> EventLoopFuture<[Domain.Fan]> {
        try provider.listFansUseCase(())
    }
}

extension Domain.Fan: Content {}
extension Domain.CreateFanInput: Content {}
