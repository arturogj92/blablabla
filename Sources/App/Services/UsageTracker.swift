import Foundation

@MainActor
final class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    @Published private(set) var totalSeconds: Double
    @Published private(set) var sessionCount: Int

    private let defaults = UserDefaults.standard

    private init() {
        self.totalSeconds = defaults.double(forKey: "usage.totalSeconds")
        self.sessionCount = defaults.integer(forKey: "usage.sessionCount")
    }

    func addSession(seconds: Double) {
        totalSeconds += seconds
        sessionCount += 1
        defaults.set(totalSeconds, forKey: "usage.totalSeconds")
        defaults.set(sessionCount, forKey: "usage.sessionCount")
    }

    func reset() {
        totalSeconds = 0
        sessionCount = 0
        defaults.set(0.0, forKey: "usage.totalSeconds")
        defaults.set(0, forKey: "usage.sessionCount")
    }

    var formattedDuration: String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let secs = Int(totalSeconds) % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    /// Estimated cost at $0.37/hour for real-time streaming
    var estimatedCost: String {
        let cost = (totalSeconds / 3600.0) * 0.37
        return String(format: "$%.4f", cost)
    }
}
