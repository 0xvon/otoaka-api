public struct PageMetadata: Codable {
    /// Current page number. Starts at `1`.
    public let page: Int

    /// Max items per page.
    public let per: Int

    /// Total number of items available.
    public let total: Int

    public init(page: Int, per: Int, total: Int) {
        self.page = page
        self.per = per
        self.total = total
    }
}

public struct Page<T> {
    public let items: [T]
    public let metadata: PageMetadata

    public init(items: [T], metadata: PageMetadata) {
        self.items = items
        self.metadata = metadata
    }
}
