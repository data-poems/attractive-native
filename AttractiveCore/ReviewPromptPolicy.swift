import Foundation

/// Durable review-request history. The app stores this alongside lesson
/// progress so eligibility survives updates and relaunches.
public struct ReviewPromptHistory: Codable, Equatable, Sendable {
    public var firstUseDate: Date
    public var activeSessionCount: Int
    public var lastSessionStartDate: Date?
    public var lastRequestDate: Date?
    public var lastRequestedVersion: String?

    public init(firstUseDate: Date,
                activeSessionCount: Int = 0,
                lastSessionStartDate: Date? = nil,
                lastRequestDate: Date? = nil,
                lastRequestedVersion: String? = nil) {
        self.firstUseDate = firstUseDate
        self.activeSessionCount = activeSessionCount
        self.lastSessionStartDate = lastSessionStartDate
        self.lastRequestDate = lastRequestDate
        self.lastRequestedVersion = lastRequestedVersion
    }

    /// Count a foreground activation as a new session only after a meaningful
    /// break. This avoids inflating the count for brief system interruptions.
    @discardableResult
    public mutating func recordActiveSession(at date: Date,
                                             minimumInterval: TimeInterval = 30 * 60) -> Bool {
        if let lastSessionStartDate,
           date.timeIntervalSince(lastSessionStartDate) < minimumInterval {
            return false
        }

        activeSessionCount += 1
        lastSessionStartDate = date
        return true
    }

    public mutating func recordRequest(version: String, at date: Date) {
        lastRequestedVersion = version
        lastRequestDate = date
    }
}

/// Product policy for asking for an App Store review after sustained use and a
/// real learning milestone. Whether StoreKit displays a prompt remains Apple's
/// decision.
public struct ReviewPromptPolicy: Sendable {
    public let minimumCompletedLessons: Int
    public let minimumActiveSessions: Int
    public let minimumFirstUseAge: TimeInterval
    public let requestCooldown: TimeInterval

    public init(minimumCompletedLessons: Int = 2,
                minimumActiveSessions: Int = 3,
                minimumFirstUseAge: TimeInterval = 7 * 24 * 60 * 60,
                requestCooldown: TimeInterval = 120 * 24 * 60 * 60) {
        self.minimumCompletedLessons = minimumCompletedLessons
        self.minimumActiveSessions = minimumActiveSessions
        self.minimumFirstUseAge = minimumFirstUseAge
        self.requestCooldown = requestCooldown
    }

    public func isEligible(completedLessonIDs: Set<String>,
                           history: ReviewPromptHistory,
                           currentVersion: String,
                           now: Date,
                           forceEligible: Bool = false) -> Bool {
        if forceEligible { return true }
        guard completedLessonIDs.count >= minimumCompletedLessons,
              history.activeSessionCount >= minimumActiveSessions,
              now.timeIntervalSince(history.firstUseDate) >= minimumFirstUseAge,
              history.lastRequestedVersion != currentVersion else {
            return false
        }

        if let lastRequestDate = history.lastRequestDate,
           now.timeIntervalSince(lastRequestDate) < requestCooldown {
            return false
        }

        return true
    }
}
