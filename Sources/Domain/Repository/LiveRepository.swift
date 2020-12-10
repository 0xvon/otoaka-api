import Endpoint
import Foundation
import NIO

public protocol LiveRepository {
    func create(input: CreateLive.Request, authorId: User.ID) -> EventLoopFuture<Live>
    func update(id: Live.ID, input: EditLive.Request, authorId: User.ID) -> EventLoopFuture<Live>
    func findLive(by id: Domain.Live.ID, selfUerId: Domain.User.ID) -> EventLoopFuture<
        Domain.LiveDetail?
    >

    func reserveTicket(liveId: Domain.Live.ID, user: Domain.User.ID) -> EventLoopFuture<
        Domain.Ticket
    >
    func updatePerformerStatus(
        requestId: PerformanceRequest.ID,
        status: PerformanceRequest.Status
    ) -> EventLoopFuture<Void>
    func find(requestId: PerformanceRequest.ID) -> EventLoopFuture<PerformanceRequest>

    func get(page: Int, per: Int) -> EventLoopFuture<Page<Live>>
    func get(page: Int, per: Int, group: Group.ID) -> EventLoopFuture<Page<Live>>
    func getRequests(for user: Domain.User.ID, page: Int, per: Int) -> EventLoopFuture<
        Page<PerformanceRequest>
    >
    func search(query: String, page: Int, per: Int) -> EventLoopFuture<Page<Live>>
}
