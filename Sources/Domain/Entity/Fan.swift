//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Vapor

public struct Fan: Content {
    public let id: UUID?
    public let displayName: String
    
    public init(id: UUID?, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
