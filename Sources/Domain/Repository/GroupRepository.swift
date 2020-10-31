import Foundation
import NIO

public protocol GroupRepository {
    func create(
        name: String, englishName: String?,
        biography: String?, since: Date?, artworkURL: URL?,
        hometown: String?
    ) -> EventLoopFuture<Domain.Group>

    func joinWithInvitation(invitationId: Domain.GroupInvitation.ID, artist: Domain.User.ID) -> EventLoopFuture<Void>
    func join(toGroup groupId: Group.ID, artist: User.ID) -> EventLoopFuture<Void>
    func invite(toGroup groupdId: Group.ID) -> EventLoopFuture<GroupInvitation>
    func findInvitation(by invitationId: GroupInvitation.ID) -> EventLoopFuture<GroupInvitation?>

    func isMember(of groupId: Group.ID, member: User.ID) -> EventLoopFuture<Bool>
    func isExists(by id: Group.ID) -> EventLoopFuture<Bool>
}
