//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/08.
//

import Vapor

//final class Fan: Content {
//    static let schema = "fans"
//
//    @ID(key: .id)
//    var id: UUID?
//
//    @Field(key: "display_name")
//    var displayName: String
//
//    init() { }
//
//    init(id: UUID? = nil, displayName: String) {
//        self.id = id
//        self.displayName = displayName
//    }
//}
//

struct Fan: Content {
    let id: String
    let displayName: String
}
