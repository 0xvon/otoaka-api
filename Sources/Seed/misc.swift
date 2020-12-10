import Foundation

struct Environment {
    public static func get(_ key: String) -> String? {
        return ProcessInfo.processInfo.environment[key]
    }
}
