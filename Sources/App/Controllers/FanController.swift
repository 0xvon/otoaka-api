//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Domain
import Foundation
import Vapor

struct FanController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let fans = routes.grouped("fans")
        fans.post(use: createFan)
        fans.get(use: listFans)
    }

    private let provider: Domain.FanProvider

    init(_ provider: Domain.FanProvider) {
        self.provider = provider
    }

    func createFan(req: Request) throws -> EventLoopFuture<Domain.Fan> {
        let fan = try req.content.decode(Domain.CreateFanInput.self)
        return try provider.createFanUseCase(fan)
    }
    
    func listFans(req: Request) throws -> EventLoopFuture<[Domain.Fan]> {
        return try provider.listFansUseCase(())
    }
}

extension Domain.Fan: Content {}
extension Domain.CreateFanInput: Content {}
