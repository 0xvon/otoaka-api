//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Vapor
import Foundation
import Domain

// 入力値を適切な型に変換してUseCaseに渡す役目
struct FanController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let fans = routes.grouped("fans")
//        fans.get(use: index)
        fans.post(use: createFan)
    }
    
    private let provider: Domain.FanProvider
    
    init(_ provider: Domain.FanProvider) {
        self.provider = provider
    }

//    func index(req: Request) throws -> EventLoopFuture<[Fan]> {
//        return Fan.query(on: req.db).all()
//    }
//
    func createFan(req: Request) throws -> EventLoopFuture<Domain.Fan> {
        let fan = try req.content.decode(Domain.CreateFanInput.self)
//        return try createFanUseCase.execute(fan)
        return try provider.createFanUseCase(fan)
    }
}

