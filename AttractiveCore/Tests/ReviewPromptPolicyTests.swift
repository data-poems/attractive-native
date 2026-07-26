import XCTest
@testable import AttractiveKit

final class ReviewPromptPolicyTests: XCTestCase {
    private let policy = ReviewPromptPolicy()
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testEligibleAfterTwoLessonsThreeSessionsAndSevenDays() {
        let history = ReviewPromptHistory(
            firstUseDate: now.addingTimeInterval(-8 * 24 * 60 * 60),
            activeSessionCount: 3
        )

        XCTAssertTrue(policy.isEligible(
            completedLessonIDs: ["fixed-points", "limit-cycles"],
            history: history,
            currentVersion: "1.0.2",
            now: now
        ))
    }

    func testEachEngagementThresholdIsRequired() {
        let oldEnough = now.addingTimeInterval(-8 * 24 * 60 * 60)

        XCTAssertFalse(policy.isEligible(
            completedLessonIDs: ["fixed-points"],
            history: ReviewPromptHistory(firstUseDate: oldEnough, activeSessionCount: 3),
            currentVersion: "1.0.2",
            now: now
        ))
        XCTAssertFalse(policy.isEligible(
            completedLessonIDs: ["fixed-points", "limit-cycles"],
            history: ReviewPromptHistory(firstUseDate: oldEnough, activeSessionCount: 2),
            currentVersion: "1.0.2",
            now: now
        ))
        XCTAssertFalse(policy.isEligible(
            completedLessonIDs: ["fixed-points", "limit-cycles"],
            history: ReviewPromptHistory(
                firstUseDate: now.addingTimeInterval(-6 * 24 * 60 * 60),
                activeSessionCount: 3
            ),
            currentVersion: "1.0.2",
            now: now
        ))
    }

    func testOncePerVersionAndCooldownBothApply() {
        let recentRequest = ReviewPromptHistory(
            firstUseDate: now.addingTimeInterval(-200 * 24 * 60 * 60),
            activeSessionCount: 20,
            lastRequestDate: now.addingTimeInterval(-30 * 24 * 60 * 60),
            lastRequestedVersion: "1.0.1"
        )
        let completed: Set<String> = ["fixed-points", "limit-cycles"]

        XCTAssertFalse(policy.isEligible(
            completedLessonIDs: completed,
            history: recentRequest,
            currentVersion: "1.0.2",
            now: now
        ), "A new version must still respect the 120-day cooldown")

        var oldRequest = recentRequest
        oldRequest.lastRequestDate = now.addingTimeInterval(-121 * 24 * 60 * 60)
        XCTAssertTrue(policy.isEligible(
            completedLessonIDs: completed,
            history: oldRequest,
            currentVersion: "1.0.2",
            now: now
        ))

        oldRequest.lastRequestedVersion = "1.0.2"
        XCTAssertFalse(policy.isEligible(
            completedLessonIDs: completed,
            history: oldRequest,
            currentVersion: "1.0.2",
            now: now
        ), "The same version may only attempt one request")
    }

    func testDebugOverrideBypassesProductThresholds() {
        XCTAssertTrue(policy.isEligible(
            completedLessonIDs: [],
            history: ReviewPromptHistory(firstUseDate: now),
            currentVersion: "1.0.2",
            now: now,
            forceEligible: true
        ))
    }

    func testForegroundActivationsWithinThirtyMinutesStayOneSession() {
        var history = ReviewPromptHistory(firstUseDate: now)

        XCTAssertTrue(history.recordActiveSession(at: now))
        XCTAssertFalse(history.recordActiveSession(at: now.addingTimeInterval(5 * 60)))
        XCTAssertTrue(history.recordActiveSession(at: now.addingTimeInterval(31 * 60)))
        XCTAssertEqual(history.activeSessionCount, 2)
    }
}

@MainActor
final class ReviewPromptPersistenceTests: XCTestCase {
    func testLessonAndReviewHistorySurviveRelaunch() throws {
        let suiteName = "ReviewPromptPersistenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstUse = Date(timeIntervalSince1970: 2_000_000_000)
        var settings: AttractiveSettings? = AttractiveSettings(defaults: defaults, now: firstUse)
        settings?.markLessonComplete("fixed-points")
        settings?.markLessonComplete("limit-cycles")
        settings?.recordActiveSession(at: firstUse)
        settings?.recordActiveSession(at: firstUse.addingTimeInterval(31 * 60))
        settings?.recordActiveSession(at: firstUse.addingTimeInterval(62 * 60))

        let promptDate = firstUse.addingTimeInterval(8 * 24 * 60 * 60)
        XCTAssertTrue(settings?.shouldRequestReview(
            currentVersion: "1.0.2",
            now: promptDate,
            forceEligible: false
        ) == true)
        settings?.markReviewRequested(currentVersion: "1.0.2", at: promptDate)
        settings = nil

        let restored = AttractiveSettings(defaults: defaults, now: promptDate)
        XCTAssertEqual(restored.completedLessonCount, 2)
        XCTAssertFalse(restored.shouldRequestReview(
            currentVersion: "1.0.2",
            now: promptDate.addingTimeInterval(121 * 24 * 60 * 60),
            forceEligible: false
        ))
        XCTAssertTrue(restored.isLessonComplete("fixed-points"))
        XCTAssertTrue(restored.isLessonComplete("limit-cycles"))
    }
}
