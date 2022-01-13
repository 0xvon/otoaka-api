import Foundation
import NIO

public enum GroupUpdateError: Swift.Error {
    case invalidEmptyId(String)
}

public struct CreateGroupUseCase: LegacyUseCase {
    public typealias Request = (input: CreateGroup.Request, user: User.ID)
    public typealias Response = Group
    
    public enum Error: Swift.Error {
        case groupAlreadyExists
    }

    public let groupRepository: GroupRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        try validate(request: request.input)
        let precondition = groupRepository.search(name: request.input.name)
            .flatMapThrowing {
                guard $0 == nil else { throw Error.groupAlreadyExists }
                return
            }
        return precondition
        .flatMap {
            return groupRepository.create(input: request.input).flatMap { group in
                groupRepository
                    .join(toGroup: group.id, artist: request.user, asLeader: true)
                    .map { _ in group }
            }
        }
    }
}

public struct EditGroupUseCase: LegacyUseCase {

    public typealias Request = (
        id: Group.ID,
        input: EditGroup.Request, user: User.ID
    )
    public typealias Response = Group

    public enum Error: Swift.Error {
        case notMemberOfGroup
    }

    public let groupRepository: GroupRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
//        try validate(request: request.input)
//        let precondition = groupRepository.isMember(of: request.id, member: request.user)
//            .flatMapThrowing {
//                guard $0 else { throw Error.notMemberOfGroup }
//                return
//            }
//        return precondition.flatMap { groupRepository.update(id: request.id, input: request.input) }
        return groupRepository.update(id: request.id, input: request.input)
    }
}

private func validate(request: CreateGroup.Request) throws {
    func assertNotEmpty(_ keyPath: KeyPath<CreateGroup.Request, String?>, context: String) throws {
        if let value = request[keyPath: keyPath], value.isEmpty {
            throw GroupUpdateError.invalidEmptyId(context)
        }
    }
    try assertNotEmpty(\.twitterId, context: "Twitter ID")
    try assertNotEmpty(\.youtubeChannelId, context: "Youtube Channel ID")
}

public struct DeleteGroupUseCase: LegacyUseCase {
    public typealias Request = (id: Group.ID, user: User.ID)
    public typealias Response = Void

    public enum Error: Swift.Error {
        case notLeader
    }

    public let groupRepository: GroupRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let precondition = groupRepository.isLeader(of: request.id, member: request.user)
            .flatMapThrowing {
                guard $0 else { throw Error.notLeader }
                return
            }
        return precondition.flatMap {
            groupRepository.deleteGroup(id: request.id)
        }
    }
}

public struct InviteGroupUseCase: LegacyUseCase {
    public typealias Request = (
        artistId: User.ID, groupId: Group.ID
    )
    public typealias Response = GroupInvitation

    public enum Error: Swift.Error {
        case userNotFound
        case groupNotFound
        case notMemberOfGroup
    }

    public let groupRepository: GroupRepository
    public let userRepository: UserRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        userRepository: UserRepository,
        eventLopp: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        eventLoop = eventLopp
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let userExists = userRepository.isExists(by: request.artistId)
        let groupExists = groupRepository.isExists(by: request.groupId)
        let precondition = userExists.and(groupExists).flatMapThrowing {
            (userExists, groupExists) -> Void in
            guard userExists else { throw Error.userNotFound }
            guard groupExists else { throw Error.groupNotFound }
            return
        }
        let isMember = groupRepository.isMember(of: request.groupId, member: request.artistId)

        return precondition.flatMap {
            isMember.flatMap { isMember -> EventLoopFuture<Response> in
                guard isMember else { return eventLoop.makeFailedFuture(Error.notMemberOfGroup) }
                return groupRepository.invite(toGroup: request.groupId)
            }
        }
    }
}

public struct JoinGroupUseCase: LegacyUseCase {
    public typealias Request = (
        invitationId: GroupInvitation.ID,
        userId: User.ID
    )
    public typealias Response = Void

    public enum Error: Swift.Error {
        case userNotFound
        case groupNotFound
        case alreadyJoined
        case invitationNotFound
        case invitationAlreadyUsed
    }

    public let groupRepository: GroupRepository
    public let userRepository: UserRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        userRepository: UserRepository,
        eventLopp: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        eventLoop = eventLopp
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        let maybeInvitation = groupRepository.findInvitation(by: request.invitationId)
        let userExists = userRepository.isExists(by: request.userId)
        return maybeInvitation.and(userExists).flatMapThrowing {
            (maybeInvitation, userExists) -> GroupInvitation in
            guard let invitation = maybeInvitation else {
                throw Error.invitationNotFound
            }
            guard userExists else {
                throw Error.userNotFound
            }
            guard !invitation.invited else {
                throw Error.invitationAlreadyUsed
            }
            return invitation
        }
        .flatMap { invitation in
            groupRepository.isMember(of: invitation.group.id, member: request.userId).map {
                ($0, invitation)
            }
        }
        .flatMapThrowing { (isAlreadyJoined, invitation) -> GroupInvitation in
            guard !isAlreadyJoined else { throw Error.alreadyJoined }
            return invitation
        }
        .flatMap { invitation in
            groupRepository.joinWithInvitation(invitationId: invitation.id, artist: request.userId)
        }
    }
}

public struct ReplyPerformanceRequestUseCase: LegacyUseCase {
    public typealias Request = (
        user: User, input: Endpoint.ReplyPerformanceRequest.Request
    )
    public typealias Response = Void

    public enum Error: Swift.Error {
        case fanCannotBePerformer
        case onlyLeaderCanAccept
        case liveNotFound
    }

    public let groupRepository: GroupRepository
    public let liveRepository: LiveRepository
    public let eventLoop: EventLoop

    public init(
        groupRepository: GroupRepository,
        liveRepository: LiveRepository,
        eventLoop: EventLoop
    ) {
        self.groupRepository = groupRepository
        self.liveRepository = liveRepository
        self.eventLoop = eventLoop
    }

    public func callAsFunction(_ request: Request) throws -> EventLoopFuture<Response> {
        guard case .artist = request.user.role else {
            return eventLoop.makeFailedFuture(Error.fanCannotBePerformer)
        }
        let performanceRequest = liveRepository.find(requestId: request.input.requestId)
        let precondition = performanceRequest.map(\.group.id)
            .flatMap { groupRepository.isLeader(of: $0, member: request.user.id) }
            .flatMapThrowing {
                guard $0 else { throw Error.onlyLeaderCanAccept }
            }
        let status: PerformanceRequest.Status
        switch request.input.reply {
        case .accept: status = .accepted
        case .deny: status = .denied
        }
        return precondition.flatMap {
            liveRepository.updatePerformerStatus(
                requestId: request.input.requestId, status: status
            )
        }
    }
}
