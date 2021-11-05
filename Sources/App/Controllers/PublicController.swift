//
//  PublicController.swift
//  App
//
//  Created by Masato TSUTSUMI on 2021/11/05.
//

import Domain
import Endpoint
import Foundation
import Persistance
import Vapor
import XMLCoder

private func injectProvider<T, URI>(
    _ handler: @escaping (Request, URI, Domain.UserSocialRepository) throws -> T
)
    -> ((Request, URI) throws -> T)
{
    return { req, uri in
        let repository = Persistance.UserSocialRepository(db: req.db)
        return try handler(req, uri, repository)
    }
}

struct PublicController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        
    }
}
