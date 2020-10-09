//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Domain
import Fluent
import Foundation

public struct FanRepository: Domain.FanRepository {
    private let db: Database

    public init(db: Database) {
        self.db = db
    }

    public func create(fan: Domain.Fan) -> EventLoopFuture<Domain.Fan> {
        let fanData: Fan = fan.toData
        return fanData.create(on: db)
            .map { fan }
    }

//    func list() -> Future<[Domain.Fan]> {
//        return Fan.query(on: self.db)
//            .all()
//            .map { $0.toDomain() }
//    }
}
