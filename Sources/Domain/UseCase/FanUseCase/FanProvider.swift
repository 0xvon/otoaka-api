//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

public protocol FanProvider {
    var createFanUseCase: AnyUseCase<CreateFanInput, Fan> { get }
}
