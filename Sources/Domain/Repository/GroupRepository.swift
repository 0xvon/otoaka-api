import Foundation
import NIO

public protocol GroupRepository {
    func create(input: CreateGroup.Request) -> EventLoopFuture<Group>
    func update(id: Group.ID, input: EditGroup.Request) -> EventLoopFuture<Group>
    func joinWithInvitation(invitationId: Domain.GroupInvitation.ID, artist: Domain.User.ID)
        -> EventLoopFuture<Void>
    func join(toGroup groupId: Group.ID, artist: User.ID, asLeader: Bool) -> EventLoopFuture<Void>
    func invite(toGroup groupdId: Group.ID) -> EventLoopFuture<GroupInvitation>
    func findInvitation(by invitationId: GroupInvitation.ID) -> EventLoopFuture<GroupInvitation?>

    func isMember(of groupId: Group.ID, member: User.ID) -> EventLoopFuture<Bool>
    func findGroup(by id: Group.ID) -> EventLoopFuture<Group?>
    func isExists(by id: Group.ID) -> EventLoopFuture<Bool>
    func isLeader(of groupId: Group.ID, member: User.ID) -> EventLoopFuture<Bool>

    func get(page: Int, per: Int) -> EventLoopFuture<Page<Group>>
    func getMemberships(for artistId: User.ID) -> EventLoopFuture<[Group]>

    func createFeed(for input: CreateArtistFeed.Request, authorId: User.ID) -> EventLoopFuture<
        GroupFeed
    >
    func feeds(groupId: Group.ID, page: Int, per: Int) -> EventLoopFuture<Page<GroupFeed>>
    func search(query: String, page: Int, per: Int) -> EventLoopFuture<Page<Group>>
}

extension GroupRepository {
    public func isExists(by id: Group.ID) -> EventLoopFuture<Bool> {
        findGroup(by: id).map { $0 != nil }
    }
}
