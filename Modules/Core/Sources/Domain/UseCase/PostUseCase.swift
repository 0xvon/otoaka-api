//
//  PostUseCase.swift
//  Domain
//
//  Created by Masato TSUTSUMI on 2021/04/18.
//

import Foundation
import NIO

public struct DeletePostUseCase: UseCase {
    public typealias Request = (
        postId: Post.ID,
        userId: User.ID
    )
    public typealias Response = Void
    public enum Error: Swift.Error {
        case notAuthor
    }
    
    public let userRepository: UserRepository
    public let eventLoop: EventLoop
    
    public init(
        userRepository: UserRepository,
        eventLoop: EventLoop
    ) {
        self.userRepository = userRepository
        self.eventLoop = eventLoop
    }
    
    public func callAsFunction(_ request: (postId: Post.ID, userId: User.ID)) throws -> EventLoopFuture<Void> {
        let precondition = userRepository.getPost(postId: request.postId).flatMapThrowing {
            guard $0.author.id == request.userId else { throw Error.notAuthor }
            return
        }
        return precondition.flatMap { userRepository.deletePost(postId: request.postId) }
    }
}
