import Foundation

public struct Identifier<Target>: Equatable, RawRepresentable {
    public var rawValue: UUID
    public init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

}
