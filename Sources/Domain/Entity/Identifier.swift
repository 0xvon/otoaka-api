import Foundation

public struct Identifier<Target>: Equatable {
    public var rawValue: UUID
    public init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }
}
