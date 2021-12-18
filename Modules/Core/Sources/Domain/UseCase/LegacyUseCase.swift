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

    func callAsFunction(_ request: Request) async throws -> Response
}

public protocol LegacyUseCase {
    associatedtype Request
    associatedtype Response

    func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response>
}

public struct AnyUseCase<Request, Response>: LegacyUseCase {
    private let _callAsFunction: (_ request: Request) throws -> EventLoopFuture<Response>

    public init<U: LegacyUseCase>(_ useCase: U) where U.Request == Request, U.Response == Response {
        _callAsFunction = useCase.callAsFunction
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        try _callAsFunction(request)
    }
}
