//
//  File.swift
//  
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import Foundation

public protocol FanRepository {
    func create(fan: Fan) -> Future<Fan>
//    func list() -> Future<[Fan]>
}
