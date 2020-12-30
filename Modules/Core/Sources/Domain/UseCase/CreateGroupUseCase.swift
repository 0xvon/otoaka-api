import Foundation
import NIO

public struct CreateGroupUseCase: UseCase {
    public typealias Request = (input: CreateGroup.Request, user: User.ID)
    public typealias Response = Group

    public enum Error: Swift.Error {
        case invalidEmptyId(String)
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
        return groupRepository.create(input: request.input).flatMap { group in
            groupRepository
                .join(toGroup: group.id, artist: request.user, asLeader: true)
                .map { _ in group }
        }
    }

    func validate(request: CreateGroup.Request) throws {
        func assertNotEmpty(_ keyPath: KeyPath<CreateGroup.Request, String?>, context: String) throws {
            if let value = request[keyPath: keyPath], value.isEmpty {
                throw Error.invalidEmptyId(context)
            }
        }
        try assertNotEmpty(\.twitterId, context: "Twitter ID")
        try assertNotEmpty(\.youtubeChannelId, context: "Youtube Channel ID")
    }
}
