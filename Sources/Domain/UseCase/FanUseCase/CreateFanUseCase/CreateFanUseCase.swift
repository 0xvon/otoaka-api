//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import NIO

public struct CreateFanInput {
    public let displayName: String
}

class CreateFanUseCase: UseCase {
    typealias Request = CreateFanInput
    
    private let repository: FanRepository
    
    private init(_ repository: FanRepository) {
        self.repository = repository
    }

    public func execute(request: Request) throws -> EventLoopFuture<Fan> {
        let fan: Fan = Fan(id: nil, displayName: request.displayName)
        return repository.create(fan: fan)
    }
}
