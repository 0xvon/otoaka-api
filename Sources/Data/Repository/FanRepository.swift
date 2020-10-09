//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Foundation
import Domain
import Fluent

public struct FanRepository: Domain.FanRepository {
    
    private let db: Database
    
    init(db: Database) {
        self.db = db
    }
    
    public func create(fan: Domain.Fan) -> Future<Domain.Fan> {
        let fanData: Fan = fan.toData
        return fanData.create(on: self.db)
            .map { fan }
    }
    
//    func list() -> Future<[Domain.Fan]> {
//        return Fan.query(on: self.db)
//            .all()
//            .map { $0.toDomain() }
//    }
}
