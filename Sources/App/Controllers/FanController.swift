//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Vapor

// 入力値を適切な型に変換してUseCaseに渡す役目
struct FanController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let fans = routes.grouped("fans")
//        fans.get(use: index)
//        fans.post(use: createFan)
        fans.get("hello", use: hello)
    }
    
    func hello(req: Request) throws -> String {
        return "hello"
    }

//    func index(req: Request) throws -> EventLoopFuture<[Fan]> {
//        return Fan.query(on: req.db).all()
//    }
//
//    func createFan(req: Request) throws -> EventLoopFuture<Fan> {
//        let createFanUseCase = CreateFanUseCase()
//        let fan = try req.content.decode(Fan.self)
//        return fan.save(on: req.db).map { fan }
//    }
}

