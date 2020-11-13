import StubKit
import Endpoint
import Foundation

extension Identifier: Stubbable {
    public static func stub() -> Identifier<Target> {
        Self(UUID())
    }
}
