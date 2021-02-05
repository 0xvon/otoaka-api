import Foundation
import NIO

public enum GroupUpdateError: Swift.Error {
    case invalidEmptyId(String)
}

public struct CreateGroupUseCase: UseCase {
    public typealias Request = (input: CreateGroup.Request, user: User.ID)
    public typealias Response = Group

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
        return groupRepository.create(input: request.input).flatMap { group in
            groupRepository
                .join(toGroup: group.id, artist: request.user, asLeader: true)
                .map { _ in group }
        }
    }
}

public struct EditGroupUseCase: UseCase {
    
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
        try validate(request: request.input)
        let precondition = groupRepository.isMember(of: request.id, member: request.user).flatMapThrowing {
            guard $0 else { throw Error.notMemberOfGroup }
            return
        }
        return precondition.flatMap { groupRepository.update(id: request.id, input: request.input) }
    }
}


fileprivate func validate(request: CreateGroup.Request) throws {
    func assertNotEmpty(_ keyPath: KeyPath<CreateGroup.Request, String?>, context: String) throws {
        if let value = request[keyPath: keyPath], value.isEmpty {
            throw GroupUpdateError.invalidEmptyId(context)
        }
    }
    try assertNotEmpty(\.twitterId, context: "Twitter ID")
    try assertNotEmpty(\.youtubeChannelId, context: "Youtube Channel ID")
}


public struct DeleteGroupUseCase: UseCase {
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
        let precondition = groupRepository.isLeader(of: request.id, member: request.user).flatMapThrowing {
            guard $0 else { throw Error.notLeader }
            return
        }
        return precondition.flatMap {
            groupRepository.deleteGroup(id: request.id)
        }
    }
}
