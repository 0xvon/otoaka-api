import Foundation

struct Environment {
    public static func get(_ key: String) -> String? {
        return ProcessInfo.processInfo.environment[key]
    }
}

struct WrappingError: Error {
    let error: Error
    let message: String
}
