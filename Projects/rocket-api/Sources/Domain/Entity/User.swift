public struct User: Codable {
    public typealias ForeignID = ForeignIdentifier<User>

    public let id: ForeignID

    public init(id: ForeignID) {
        self.id = id
    }
}
