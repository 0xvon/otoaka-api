//
//  PublicUseCase.swift
//  Domain
//
//  Created by Masato TSUTSUMI on 2021/11/05.
//

import Endpoint
import Foundation
import NIO

public struct GetUserProfileUseCase: UseCase {
    public typealias Request = String
    public typealias Response = GetUserProfile.Response
    public let eventLoop: EventLoop

    public let userSocialRepository: UserSocialRepository

    public init(userSocialRepository: UserSocialRepository, eventLoop: EventLoop) {
        self.userSocialRepository = userSocialRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) async throws -> Response {
        let user = try await userSocialRepository.getUserByUsername(username: request).get()
        async let transition = userSocialRepository.getLikedLiveTransition(userId: user.id).get()
        async let frequentlyWatchingGroups = userSocialRepository.frequentlyWatchingGroups(
            userId: user.id, selfUser: user.id, page: 1, per: 50
        ).get().items
        async let recentlyFollowingGroups = userSocialRepository.recentlyFollowingGroups(
            userId: user.id, selfUser: user.id
        ).get()
        async let followingGroups = userSocialRepository.followings(
            userId: user.id, selfUser: user.id, page: 1, per: 50
        ).get().items
        async let schedule = userSocialRepository.likedLive(
            userId: user.id, selfUser: user.id, series: .future, page: 1, per: 10
        ).get().items

        return try await Response(
            user: user,
            transition: transition,
            frequentlyWatchingGroups: frequentlyWatchingGroups,
            recentlyFollowingGroups: recentlyFollowingGroups,
            followingGroups: followingGroups,
            liveSchedule: schedule
        )
    }
}
