import Domain
import NIO

private func unimplemented(
    function: StaticString = #function,
    file: StaticString = #file, line: UInt = #line
) -> Never {
    fatalError("unimplemented \"\(function)\"", file: file, line: line)
}

protocol GroupRepositoryMock: GroupRepository {}
extension GroupRepositoryMock {
    func create(input: CreateGroup.Request) -> EventLoopFuture<Group> {
        unimplemented()
    }
    func update(id: Group.ID, input: EditGroup.Request) -> EventLoopFuture<Group> {
        unimplemented()
    }
    func joinWithInvitation(invitationId: GroupInvitation.ID, artist: User.ID) -> EventLoopFuture<
        Void
    > {
        unimplemented()
    }

    func join(toGroup groupId: Group.ID, artist: User.ID, asLeader: Bool) -> EventLoopFuture<Void> {
        unimplemented()
    }

    func invite(toGroup groupdId: Group.ID) -> EventLoopFuture<GroupInvitation> {
        unimplemented()
    }

    func findInvitation(by invitationId: GroupInvitation.ID) -> EventLoopFuture<GroupInvitation?> {
        unimplemented()
    }

    func isMember(of groupId: Group.ID, member: User.ID) -> EventLoopFuture<Bool> {
        unimplemented()
    }

    func findGroup(by id: Group.ID) -> EventLoopFuture<Group?> {
        unimplemented()
    }
    func isLeader(of groupId: Group.ID, member: User.ID) -> EventLoopFuture<Bool> {
        unimplemented()
    }
    func get(page: Int, per: Int) -> EventLoopFuture<Page<Group>> { unimplemented() }
    func getMemberships(for artistId: User.ID) -> EventLoopFuture<[Group]> { unimplemented() }

    func createFeed(for input: CreateArtistFeed.Request, authorId: User.ID) -> EventLoopFuture<
        ArtistFeed
    > { unimplemented() }
    func addArtistFeedComment(userId: User.ID, input: PostFeedComment.Request) -> EventLoopFuture<
        ArtistFeedComment
    > { unimplemented() }
    func feeds(groupId: Group.ID, page: Int, per: Int) -> EventLoopFuture<Page<ArtistFeed>> {
        unimplemented()
    }
    func search(query: String, page: Int, per: Int) -> EventLoopFuture<Page<Group>> {
        unimplemented()
    }
}

protocol LiveRepositoryMock: LiveRepository {}
extension LiveRepositoryMock {
    func create(input: Endpoint.CreateLive.Request, authorId: Domain.User.ID) -> EventLoopFuture<
        Endpoint.Live
    > { unimplemented() }
    func update(id: Live.ID, input: EditLive.Request, authorId: User.ID) -> EventLoopFuture<Live> {
        unimplemented()
    }

    func findLive(by id: Domain.Live.ID, selfUerId: Domain.User.ID) -> EventLoopFuture<
        Domain.LiveDetail?
    > {
        unimplemented()
    }

    func reserveTicket(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<
        Domain.Ticket
    > {
        unimplemented()
    }

    func get(page: Int, per: Int) -> EventLoopFuture<Page<Live>> { unimplemented() }

    func updatePerformerStatus(requestId: PerformanceRequest.ID, status: PerformanceRequest.Status)
        -> EventLoopFuture<Void>
    {
        unimplemented()
    }

    func find(requestId: PerformanceRequest.ID) -> EventLoopFuture<PerformanceRequest> {
        unimplemented()
    }
    func getRequests(for user: User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<PerformanceRequest>
    > {
        unimplemented()
    }
    func get(page: Int, per: Int, group: Group.ID) -> EventLoopFuture<Page<Live>> {
        unimplemented()
    }
    func search(query: String, page: Int, per: Int) -> EventLoopFuture<Page<Live>> {
        unimplemented()
    }
    func getUserTickets(userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.Ticket>
    > {
        unimplemented()
    }
}
