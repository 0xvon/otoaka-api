//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Domain
import Foundation
import Vapor

// 入力値を適切な型に変換してUseCaseに渡す役目
struct FanController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let fans = routes.grouped("fans")
        fans.post(use: createFan)
    }

    private let provider: Domain.FanProvider

    init(_ provider: Domain.FanProvider) {
        self.provider = provider
    }

    func createFan(req: Request) throws -> EventLoopFuture<Domain.Fan> {
        let fan = try req.content.decode(Domain.CreateFanInput.self)
        return try provider.createFanUseCase(fan)
    }
}

extension Domain.Fan: Content {}
extension Domain.CreateFanInput: Content {}
