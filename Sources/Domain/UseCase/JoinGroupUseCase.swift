import NIO

public struct JoinGroupUseCase: UseCase {
    public typealias Request = (
        invitationId: GroupInvitation.ID,
        userId: User.ID
    )
    public typealias Response = Void

    public enum Error: Swift.Error {
        case userNotFound
        case groupNotFound
        case invitationNotFound
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
        return maybeInvitation.and(userExists).flatMapThrowing { (maybeInvitation, userExists) -> GroupInvitation in
            guard let invitation = maybeInvitation else {
                throw Error.invitationNotFound
            }
            guard userExists else {
                throw Error.userNotFound
            }
            return invitation
        }
        .flatMap { invitation in
            groupRepository.join(toGroup: invitation.group.id, artist: request.userId)
        }
    }
}
