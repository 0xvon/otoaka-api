//
//  PostUseCase.swift
//  Domain
//
//  Created by Masato TSUTSUMI on 2021/04/18.
//

import Foundation
import NIO

public struct CreatePostUserCase: LegacyUseCase {
    public typealias Request = (
        user: User, input: CreatePost.Request
    )
    public typealias Response = Post
    public let userRepository: UserRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        userRepository: UserRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let post = userRepository.createPost(for: request.input, authorId: request.user.id)
        return post.flatMap { post in
            if !post.isPrivate {
                let notification = PushNotification(message: "\(request.user.name)がライブレポートを投稿しました")
                return notificationService.publish(
                    toUserFollowers: request.user.id, notification: notification
                )
                .map { post }
            }
            return eventLoop.makeSucceededFuture(post)
        }
    }
}

public struct DeletePostUseCase: LegacyUseCase {
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

    public func callAsFunction(_ request: (postId: Post.ID, userId: User.ID)) throws
        -> EventLoopFuture<Void>
    {
        let precondition = userRepository.getPost(postId: request.postId).flatMapThrowing {
            guard $0.author.id == request.userId else { throw Error.notAuthor }
            return
        }
        return precondition.flatMap { userRepository.deletePost(postId: request.postId) }
    }
}

public struct AddPostCommentUseCase: LegacyUseCase {
    public typealias Request = (
        user: User, input: AddPostComment.Request
    )
    public typealias Response = PostComment
    public let userRepository: UserRepository
    public let notificationService: PushNotificationService
    public let eventLoop: EventLoop

    public init(
        userRepository: UserRepository,
        notificationService: PushNotificationService,
        eventLoop: EventLoop
    ) {
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let postComment = userRepository.addPostComment(
            userId: request.user.id, input: request.input)
        let post = userRepository.getPost(postId: request.input.postId)
        return
            postComment
            .and(post)
            .flatMap { (comment, post) in
                if comment.author.id != post.author.id {
                    let notification = PushNotification(
                        message: "\(comment.author.name)があなたのレポートにコメントしました")
                    return notificationService.publish(
                        to: post.author.id, notification: notification
                    )
                    .map { comment }
                }
                return eventLoop.makeSucceededFuture(comment)
            }
    }
}
