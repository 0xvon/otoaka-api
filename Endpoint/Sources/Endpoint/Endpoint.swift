public enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

public protocol Endpoint {
    associatedtype Request: Codable
    associatedtype Response: Codable
    associatedtype URIInput

    static var method: HTTPMethod { get }
    static var path: Route<URIInput> { get }
}

public struct Empty: Codable {}

public struct Signup: Endpoint {
    public struct Request: Codable {
        public var displayName: String
    }
    public struct Response: Codable {
        public var displayName: String
    }
    public static let method: HTTPMethod = .post
    public static let path = const("signup")
}

public struct GetBand: Endpoint {
    public typealias Request = Empty
    public typealias Response = Empty
    public static let method: HTTPMethod = .get
    public static let path = const("bands")/int()
}

public struct Route<Value> {
    let parse: ([String]) -> ([String], Value)?
    let build: ([String], Value) -> [String]
}

extension Route {
    public func runParse(_ pathComponents: [String]) -> Value? {
        self.parse(pathComponents)?.1
    }
    public func runBuild(_ value: Value) -> [String] {
        self.build([], value)
    }
    
    public func map<NewValue>(parse mapParse: @escaping (Value) -> NewValue,
                              build mapBuild: @escaping (NewValue) -> Value
    ) -> Route<NewValue> {
        Route<NewValue>(
            parse: {
                guard let (rest, value) = self.parse($0) else { return nil }
                return (rest, mapParse(value))
            },
            build: { self.build($0, mapBuild($1)) }
        )
    }
}

public extension Route {
    static func join<Value2>(lhs: Self, rhs: Route<Value2>) -> Route<(Value, Value2)> {
        Route<(Value, Value2)>(
            parse: { (pathComponents1: [String]) -> ([String], (Value, Value2))? in
                guard let (pathComponents2, value) = lhs.parse(pathComponents1),
                      let (pathComponents3, value2) = rhs.parse(pathComponents2) else {
                    return nil
                }
                return (pathComponents3, (value, value2))
            },
            build: { pathComponents1, values -> [String] in
                let (value, value2) = values
                let pathComponents2 = lhs.build(pathComponents1, value)
                return rhs.build(pathComponents2, value2)
            }
        )
    }
    static func / <Value2>(lhs: Self, rhs: Route<Value2>) -> Route<(Value, Value2)> {
        join(lhs: lhs, rhs: rhs)
    }

    static func / (lhs: Self, rhs: Route<Void>) -> Route<Value> {
        join(lhs: lhs, rhs: rhs).map(parse: \.0, build: { ($0, ()) })
    }
}

public extension Route where Value == Void {
    static func / <Value2>(lhs: Self, rhs: Route<Value2>) -> Route<Value2> {
        join(lhs: lhs, rhs: rhs).map(parse: \.1, build: { ((), $0) })
    }
}


internal func uncons<C: Collection>(_ xs: C) -> (C.Iterator.Element, C.SubSequence)?
{
    if let head = xs.first {
        let secondIndex = xs.index(after: xs.startIndex)
        return (head, xs.suffix(from: secondIndex))
    }
    else {
        return nil
    }
}

func captureHead<Value>(
    parse: @escaping (String) -> Value?,
    build: @escaping (Value) -> String
) -> Route<Value> {
    Route<Value>(
        parse: { pathComponents in
            if let (first, rest) = uncons(pathComponents), let parsed = parse(first) {
                return (Array(rest), parsed)
            }
            return nil
        },
        build: { (pathComponents, value) in
            pathComponents + [build(value)]
        }
    )
}


public func const(_ string: String) -> Route<()> {
    captureHead(
        parse: { $0 == string ? () : nil },
        build: { string }
    )
}

public func int() -> Route<Int> {
    captureHead(parse: Int.init, build: \.description)
}

public func string() -> Route<String> {
    captureHead(parse: String.init, build: { $0 })
}
