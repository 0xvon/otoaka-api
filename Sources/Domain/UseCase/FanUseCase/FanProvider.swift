//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

public struct FanProvider {
    private let repository: Domain.FanRepository
    public let createFanUseCase: AnyUseCase<CreateFanInput, Fan>

    public init(_ repository: Domain.FanRepository) {
        self.repository = repository
        createFanUseCase = AnyUseCase(CreateFanUseCase(repository))
    }
}
