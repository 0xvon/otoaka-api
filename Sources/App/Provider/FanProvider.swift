//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Foundation
import Vapor
import Domain
import Data

struct FanProvider: Domain.FanProvider {
    private let repository: Domain.FanRepository

    init(_ container: Container) throws {
        self.repository = try container.make(FanRepository.self)
    }
}
