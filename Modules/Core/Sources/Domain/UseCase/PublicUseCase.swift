//
//  PublicUseCase.swift
//  Domain
//
//  Created by Masato TSUTSUMI on 2021/11/05.
//

import Endpoint
import Foundation
import NIO

public struct GetUserProfileUseCase: LegacyUseCase {
    public typealias Request = String
    public typealias Response = GetUserProfile.Response
    public let eventLoop: EventLoop

    public let userSocialRepository: UserSocialRepository

    public init(userSocialRepository: UserSocialRepository, eventLoop: EventLoop) {
        self.userSocialRepository = userSocialRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let user = userSocialRepository.getUserByUsername(username: request)

        return user.flatMap { user -> EventLoopFuture<Response> in
            let transition = userSocialRepository.getLikedLiveTransition(userId: user.id)
            let frequentlyWatchingGroups = userSocialRepository.frequentlyWatchingGroups(
                userId: user.id, selfUser: user.id, page: 1, per: 50
            ).map { $0.items }
            let recentlyFollowingGroups = userSocialRepository.recentlyFollowingGroups(
                userId: user.id, selfUser: user.id)
            let followingGroups = userSocialRepository.followings(
                userId: user.id, selfUser: user.id, page: 1, per: 50
            )
            .map { $0.items }
            let schedule = userSocialRepository.likedLive(
                userId: user.id, selfUser: user.id, series: .future, page: 1, per: 10
            )
            .map { $0.items }

            return
                transition
                .and(frequentlyWatchingGroups)
                .and(recentlyFollowingGroups)
                .and(followingGroups)
                .and(schedule)
                .map {
                    (
                        $0.0.0.0.0,
                        $0.0.0.0.1,
                        $0.0.0.1,
                        $0.0.1,
                        $0.1
                    )
                }
                .map {
                    Response(
                        user: user,
                        transition: $0,
                        frequentlyWatchingGroups: $1,
                        recentlyFollowingGroups: $2,
                        followingGroups: $3,
                        liveSchedule: $4
                    )
                }
        }
    }
}
