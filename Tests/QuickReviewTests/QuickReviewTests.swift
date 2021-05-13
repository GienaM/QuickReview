//
//  QuickReviewTests.swift
//
//  Copyright © 2021 Gienadij Mackiewicz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
@testable import QuickReview
    
final class QuickReviewTests: XCTestCase {

    // MARK: - Tear down

    override func tearDown() {
        launchesUntilRequest = 10
        daysUntilRequest = 10
        requestIfRated = true
        daysUntilResetCounters = 60
        requestOnRatedVersion = false
        previewMode = false
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }

    func testConfigure_shouldNotCreateNewObject_whenCalledMoreThanOnce() {
        configure()
        let instance = QuickReview.shared
        configure()
        let newInstance = QuickReview.shared
        XCTAssert(instance === newInstance)
    }

    func testRequestReviewInterface_shouldMutateIsRated_whenCanRequest() {
        configure()
        let calendar = Calendar.current
        QuickReview.shared.firstLaunchDate = calendar.date(byAdding: .day, value: -15, to: Date())
        QuickReview.shared.launchCount = 55
        requestReview()
        XCTAssertTrue(QuickReview.shared.isRated)
    }

    func testDaysSinceFirstLaunch_shouldReturnZero_whenIsNotRated() {
        let quickReview = QuickReview()
        XCTAssertEqual(quickReview.daysSinceFirstLaunch, 0)
        quickReview.firstLaunchDate = nil
        XCTAssertEqual(quickReview.daysSinceFirstLaunch, 0)
    }

    func testDaysSinceRated_shouldReturnZero_whenIsNotRated() {
        let quickReview = QuickReview()
        let calendar = Calendar.current
        XCTAssertEqual(quickReview.daysSinceRated, 0)
        quickReview.launchCount = 10
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -10, to: Date())
        quickReview.requestReview()
        quickReview.lastRateDate = calendar.date(byAdding: .day, value: -60, to: Date())
        requestOnRatedVersion = true
        quickReview.resetIfNeeded()
        XCTAssertEqual(quickReview.daysSinceRated, 0)
    }

    func testLaunchCount_shouldIncrement_whenWillEnterForegroundNotificationIsReceived() {
        let quickReview = QuickReview()
        XCTAssertEqual(quickReview.launchCount, 1)
        let calendar = Calendar.current
        quickReview.resignActiveDate = calendar.date(byAdding: .second, value: -181, to: Date())
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil)
        let expectation = expectation(description: "Wait for 0.1 second")
        usleep(100000)
        expectation.fulfill()
        wait(for: [expectation], timeout: 0.2)
        XCTAssertEqual(quickReview.launchCount, 2)
        XCTAssertNil(quickReview.resignActiveDate)
    }

    func testResignActiveDate_shouldChange_whenWillResignActiveNotificationIsReceived() {
        let quickReview = QuickReview()
        NotificationCenter.default.post(
            name: UIApplication.willResignActiveNotification, object: nil)
        let expectation = expectation(description: "Wait for 0.1 second")
        usleep(100000)
        expectation.fulfill()
        wait(for: [expectation], timeout: 0.2)
        XCTAssertNotNil(quickReview.resignActiveDate)
    }

    func testCanRequest_shouldReturnFalse_forDefaultInitialState() {
        XCTAssertFalse(QuickReview().canRequest())
    }

    func testCanRequest_shouldReturnFalse_whenOnlyLaunchCountFulfilled() {
        let quickReview = QuickReview()
        quickReview.launchCount = 10
        XCTAssertFalse(quickReview.canRequest())
    }

    func testCanReuest_shouldReturnFalse_whenOnlyDaysSinceFirstLaunchFulfilled() {
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -10, to: Date())
        XCTAssertFalse(quickReview.canRequest())
    }

    func testCanRequest_shouldReturnFalse_whenIsRated() {
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.launchCount = 10
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -10, to: Date())
        quickReview.requestReview()
        XCTAssertFalse(quickReview.canRequest())
    }

    func testCanRequest_shouldReturnTrue_whenBothConditionsFulfilled() {
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.launchCount = 10
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -10, to: Date())
        XCTAssertTrue(quickReview.canRequest())
    }

    func testRequestReview_shouldNotChangeIsRated_whenInPreviewMode() {
        let quickReview = QuickReview()
        previewMode = true
        quickReview.requestReview()
        XCTAssertFalse(quickReview.isRated)
    }

    func testRequestReview_shouldChangeIsRated_whenCanRequestIsTrue() {
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.launchCount = 11
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -11, to: Date())
        quickReview.requestReview()
        XCTAssertTrue(quickReview.isRated)
    }

    func testRequestReview_shouldRateMultipleTimes_whenConditionsAreMet() {
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.launchCount = 11
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -11, to: Date())
        quickReview.requestReview()
        XCTAssertTrue(quickReview.isRated)
        quickReview.lastRateDate = calendar.date(byAdding: .day, value: -60, to: Date())
        let expectation = expectation(description: "Wait for 1 second")
        sleep(1)
        expectation.fulfill()
        quickReview.resetIfNeeded()
        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(quickReview.isRated)
        quickReview.launchCount = 10
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -10, to: Date())
        quickReview.requestReview()
        XCTAssertTrue(quickReview.isRated)
    }

    func testResetIfNeeded_shouldClearData_whenAllConditionsAreMet() {
        requestOnRatedVersion = true
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.launchCount = 12
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -20, to: Date())
        quickReview.requestReview()
        quickReview.lastRateDate = calendar.date(byAdding: .day, value: -60, to: Date())
        quickReview.resetIfNeeded()
        XCTAssertFalse(quickReview.isRated)
        XCTAssertEqual(quickReview.launchCount, 0)
        XCTAssertEqual(quickReview.firstLaunchDate, nil)
        XCTAssertEqual(quickReview.lastRateDate, nil)
    }

    func testResetIfNeeded_shouldNotClearData_whenRequestIfRatedIsFalse() {
        requestIfRated = false
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.launchCount = 12
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -20, to: Date())
        quickReview.requestReview()
        quickReview.lastRateDate = calendar.date(byAdding: .day, value: -60, to: Date())
        quickReview.resetIfNeeded()
        XCTAssertTrue(quickReview.isRated)
        XCTAssertNotEqual(quickReview.launchCount, 0)
        XCTAssertNotEqual(quickReview.firstLaunchDate, nil)
        XCTAssertNotEqual(quickReview.lastRateDate, nil)
    }

    func testResetIfNeeded_shouldNotClearData_whenRequestOnRatedVersionIsFalse() {
        requestOnRatedVersion = false
        let quickReview = QuickReview()
        let calendar = Calendar.current
        quickReview.launchCount = 12
        quickReview.firstLaunchDate = calendar.date(byAdding: .day, value: -20, to: Date())
        quickReview.requestReview()
        quickReview.lastRateDate = calendar.date(byAdding: .day, value: -60, to: Date())
        quickReview.resetIfNeeded()
        XCTAssertTrue(quickReview.isRated)
        XCTAssertNotEqual(quickReview.launchCount, 0)
        XCTAssertNotEqual(quickReview.firstLaunchDate, nil)
        XCTAssertNotEqual(quickReview.lastRateDate, nil)
    }
}
