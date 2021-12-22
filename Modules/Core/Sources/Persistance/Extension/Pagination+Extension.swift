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
        // `withoutActuallyEscaping` is safe here because `TaskGroup` captures `item` closure
        // but `TaskGroup`'s lifetime is limited in this scope.
        // The `item` is captured by coroutine frame due to coroutine splitting, but the
        // frame's lifetime is upper bounded by the caller frame.
        let items = try await withoutActuallyEscaping(item) { escapedItem in
            try await withOrderedTaskGroup(of: Item.self) { group -> [Item] in
                for pageItem in page.items {
                    group.addTask {
                        return try await escapedItem(pageItem)
                    }
                }
                var items: [Item] = []
                items.reserveCapacity(page.items.count)
                for try await item in group {
                    items.append(item)
                }
                return items
            }
        }
        return Endpoint.Page(items: items, metadata: metadata)
    }
}
