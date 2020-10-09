//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Foundation
import NIO

public protocol UseCase {
    associatedtype Request
    associatedtype Response
    
    func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response>
}

public struct AnyUseCase<Request, Response>: UseCase {
    
    private let _callAsFunction: (_ request: Request) throws -> EventLoopFuture<Response>
    
    public init<U: UseCase>(_ useCase: U) where U.Request == Request, U.Response == Response {
        _callAsFunction = useCase.callAsFunction
    }
    
    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        return try _callAsFunction(request)
    }
}
