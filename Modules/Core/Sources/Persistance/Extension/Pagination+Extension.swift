import Endpoint
import FluentKit

extension Endpoint.Page {
    static func translate<T>(
        page: FluentKit.Page<T>, eventLoop: EventLoop, item: (T) -> EventLoopFuture<Item>
    ) -> EventLoopFuture<Endpoint.Page<Item>> {
        let metadata = Endpoint.PageMetadata(
            page: page.metadata.page, per: page.metadata.per, total: page.metadata.total)
        let items = page.items.map { item($0) }.flatten(on: eventLoop)
        return items.map { Endpoint.Page(items: $0, metadata: metadata) }
    }

    static func translate<T>(
        page: FluentKit.Page<T>, item: (T) async throws -> Item
    ) async throws -> Endpoint.Page<Item> {
        let metadata = Endpoint.PageMetadata(
            page: page.metadata.page, per: page.metadata.per, total: page.metadata.total)
        let items = try await page.items.asyncMap(item)
        return Endpoint.Page(items: items, metadata: metadata)
    }
}
