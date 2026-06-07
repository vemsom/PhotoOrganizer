import Foundation

/// Logg med händelser under körning.
@MainActor
final class OperationLog: ObservableObject {
    enum Level: String { case info, warn, error, success }

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let message: String
    }

    @Published private(set) var entries: [Entry] = []

    func log(_ level: Level, _ message: String) {
        entries.append(Entry(timestamp: Date(), level: level, message: message))
    }

    func clear() { entries.removeAll() }

    func exportAsText() -> String {
        let df = ISO8601DateFormatter()
        return entries.map { "[\(df.string(from: $0.timestamp))] \($0.level.rawValue.uppercased()): \($0.message)" }
            .joined(separator: "\n")
    }
}
