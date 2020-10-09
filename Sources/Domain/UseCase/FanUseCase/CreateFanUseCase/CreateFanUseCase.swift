//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import NIO

public struct CreateFanInput: Codable {
    public let displayName: String
}

public class CreateFanUseCase: UseCase {
    public typealias Request = CreateFanInput
    public typealias Response = Fan
    
    private let repository: FanRepository
    
    internal init(_ repository: FanRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let fan: Fan = Fan(id: nil, displayName: request.displayName)
        return repository.create(fan: fan)
    }
}
