//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Foundation

public protocol FanProvider {
    var createFanUseCase: UseCase<CreateFanInput, Fan> { get }
}
