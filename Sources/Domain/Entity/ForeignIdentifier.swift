public struct ForeignIdentifier<Entity>: Codable, ExpressibleByStringLiteral, Hashable {
    let value: String
    
    public init(value: String) {
        self.value = value
    }

    public init(stringLiteral string: String) {
        self.init(value: string)
    }
}
