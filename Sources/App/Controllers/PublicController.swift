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
    _ handler: @escaping (Request, URI, Domain.UserSocialRepository) async throws -> T
)
    -> ((Request, URI) async throws -> T)
{
    return { req, uri in
        let repository = Persistance.UserSocialRepository(db: req.db)
        return try await handler(req, uri, repository)
    }
}

struct PublicController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        try routes.on(
            endpoint: GetUserProfile.self,
            use: injectProvider { req, uri, repository in
                let useCase = GetUserProfileUseCase(
                    userSocialRepository: repository, eventLoop: req.eventLoop)
                return try await useCase(uri.username)
            })
    }
}

extension GetUserProfile.Response: Content {}
