import Foundation
import NIO

public protocol GroupRepository {
    func create(input: Endpoint.CreateGroup.Request) -> EventLoopFuture<Domain.Group>

    func joinWithInvitation(invitationId: Domain.GroupInvitation.ID, artist: Domain.User.ID)
        -> EventLoopFuture<Void>
    func join(toGroup groupId: Group.ID, artist: User.ID, asLeader: Bool) -> EventLoopFuture<Void>
    func invite(toGroup groupdId: Group.ID) -> EventLoopFuture<GroupInvitation>
    func findInvitation(by invitationId: GroupInvitation.ID) -> EventLoopFuture<GroupInvitation?>

    func isMember(of groupId: Group.ID, member: User.ID) -> EventLoopFuture<Bool>
    func findGroup(by id: Group.ID) -> EventLoopFuture<Group?>
    func isExists(by id: Group.ID) -> EventLoopFuture<Bool>
}

extension GroupRepository {
    public func isExists(by id: Group.ID) -> EventLoopFuture<Bool> {
        findGroup(by: id).map { $0 != nil }
    }
}
