import Foundation

public struct Identifier<Target> {
    public var rawValue: UUID
    public init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }
}
