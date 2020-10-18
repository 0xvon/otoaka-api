//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Domain
import Fluent
import Foundation

//public struct FanRepository: Domain.FanRepository {
//    private let db: Database
//
//    public init(db: Database) {
//        self.db = db
//    }
//
//    public func create(fan: Domain.Fan) -> EventLoopFuture<Domain.Fan> {
//        return fan.asPersistance().create(on: db)
//            .map { fan }
//    }
//
//    public func list() -> EventLoopFuture<[Domain.Fan]> {
//        Fan.query(on: db)
//            .all()
//            .flatMapThrowing { try $0.map(Domain.Fan.init(fromPersistance: )) }
//    }
//}
