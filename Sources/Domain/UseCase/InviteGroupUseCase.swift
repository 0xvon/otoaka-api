import NIO

public struct InviteGroupUseCase: UseCase {
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
