//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Vapor


class CreateFanUseCase: AnyUseCase {
    private let repository: FanRepository
    
    private init(_ repository: FanRepository) {
        self.repository = repository
    }
    
    public func execute(request: CreateFanInput) throws -> EventLoopFuture<Fan> {
        let fan: Fan = Fan(id: nil, displayName: request.displayName)
        return repository.create(fan: fan)
    }
}
