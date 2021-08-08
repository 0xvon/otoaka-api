import Endpoint
import Foundation
import NIO

public protocol LiveRepository {
    func create(input: CreateLive.Request) -> EventLoopFuture<Live>
    func update(id: Live.ID, input: EditLive.Request) -> EventLoopFuture<Live>
    func fetch(input: Domain.CreateLive.Request) -> EventLoopFuture<Domain.Live>
    func getLiveDetail(by id: Domain.Live.ID, selfUserId: Domain.User.ID) -> EventLoopFuture<
        Domain.LiveDetail?
    >
    func getLive(by id: Domain.Live.ID) -> EventLoopFuture<Domain.Live?>
    func getLive(by piaEventCode: String) -> EventLoopFuture<Domain.Live?>
    func getParticipants(liveId: Domain.Live.ID, page: Int, per: Int) -> EventLoopFuture<Domain.Page<Domain.User>>

    func reserveTicket(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<
        Void
    >
    func refundTicket(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<
        Void
    >
    func updatePerformerStatus(
        requestId: PerformanceRequest.ID,
        status: PerformanceRequest.Status
    ) -> EventLoopFuture<Void>
    func find(requestId: PerformanceRequest.ID) -> EventLoopFuture<PerformanceRequest>
    func getUserTickets(userId: Domain.User.ID, selfUser: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Domain.Page<Domain.LiveFeed>
    >

    func get(selfUser: User.ID, page: Int, per: Int) -> EventLoopFuture<Page<LiveFeed>>
    func get(selfUser: Domain.User.ID, page: Int, per: Int, group: Group.ID) -> EventLoopFuture<Page<LiveFeed>>
    func getRequests(for user: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<PerformanceRequest>
    >
    func getPendingRequestCount(for user: Domain.User.ID) -> EventLoopFuture<Int>
    func search(selfUser: Domain.User.ID, query: String, page: Int, per: Int) -> EventLoopFuture<Page<LiveFeed>>
    func getLivePosts(liveId: Domain.Live.ID, userId: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<Page<PostSummary>>
}
