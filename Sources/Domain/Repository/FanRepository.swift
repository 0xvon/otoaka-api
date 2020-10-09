//
//  File.swift
//
//
//  Created by Masato TSUTSUMI on 2020/10/09.
//

import NIO

public protocol FanRepository {
    func create(fan: Fan) -> EventLoopFuture<Fan>
//    func list() -> Future<[Fan]>
}
