//
//  QuickReview.swift
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

import StoreKit
import Combine
import UIKit


// MARK: - Public interface

public var launchesUntilRequest: Int = 10
public var daysUntilRequest: Int = 10
public var requestIfRated: Bool = true
public var daysUntilResetCounters: Int = 60
public var requestOnRatedVersion: Bool = false
public var previewMode: Bool = false
public func configure() {
    _ = QuickReview.shared
}
public func requestReview() {
    QuickReview.shared.requestReview()
}

// MARK: - Implementation

internal final class QuickReview {

    // MARK: - Internal properties

    var cancellables: Set<AnyCancellable> = []
    var resignActiveDate: Date?

    static var shared: QuickReview {
        struct Singleton {
            static let instance: QuickReview = QuickReview()
        }
        return Singleton.instance
    }

    var storage: UserDefaults {
        return UserDefaults.standard
    }

    var isRated: Bool {
        return storage.value(forKey: UserDefaultsKeys.lastRateDate) != nil
    }

    var firstLaunchDate: Date? {
        get {
            let key = UserDefaultsKeys.firstLaunchDate
            let timeIntervalSince1970: TimeInterval = storage.double(forKey: key)
            guard timeIntervalSince1970 != .zero else { return nil }

            return Date(timeIntervalSince1970: timeIntervalSince1970)
        }
        set {
            let key = UserDefaultsKeys.firstLaunchDate
            let value = newValue?.timeIntervalSince1970
            storage.setValue(value, forKey: key)
        }
    }

    var daysSinceFirstLaunch: Int {
        let calendar = Calendar.current
        guard let firstLaunchDate = firstLaunchDate else {
            return .zero
        }

        return calendar.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
    }

    var launchCount: Int {
        get { storage.integer(forKey: UserDefaultsKeys.launchCount) }
        set { storage.setValue(newValue, forKey: UserDefaultsKeys.launchCount) }
    }

    var lastRateDate: Date? {
        get {
            let key = UserDefaultsKeys.lastRateDate
            let timeIntervalSince1970 = storage.double(forKey: key)
            guard timeIntervalSince1970 != .zero else { return nil }

            return Date(timeIntervalSince1970: timeIntervalSince1970)
        }
        set {
            let key = UserDefaultsKeys.lastRateDate
            let value = newValue?.timeIntervalSince1970
            storage.setValue(value, forKey: key)
        }
    }

    var daysSinceRated: Int {
        let calendar = Calendar.current
        guard let lastRateDate = lastRateDate else {
            return .zero
        }

        return calendar.dateComponents([.day], from: lastRateDate, to: Date()).day ?? 0
    }

    var currentVersion: String? {
        #if SWIFT_PACKAGE
        return Calendar.current.component(.second, from: Date()).description
        #else
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        #endif
    }

    var lastRatedVersion: String? {
        get { storage.string(forKey: UserDefaultsKeys.lastRatedVersion) }
        set { storage.setValue(newValue, forKey: UserDefaultsKeys.lastRatedVersion) }
    }

    // MARK: - Initialization

    init() {
        resetIfNeeded()
        addApplicationObservers()
        setFirstLaunchDateIfNeeded()
        incrementLaunchCount()
    }

    // MARK: - Request review

    func requestReview() {
        guard previewMode == false else {
            SKStoreReviewController.requestReview()
            return
        }

        if canRequest() == true {
            SKStoreReviewController.requestReview()
            storeRatedVersionDetails()
        }
    }

    // MARK: - Helpers

    func canRequest() -> Bool {
        guard isRated == false else {
            return false
        }
        
        let daysConditionFulfilled = daysSinceFirstLaunch >= daysUntilRequest
        let launchesConditionFulfilled = launchCount >= launchesUntilRequest

        return daysConditionFulfilled && launchesConditionFulfilled
    }

    func resetIfNeeded() {
        guard isRated, requestIfRated, daysSinceRated >= daysUntilResetCounters else {
            return
        }

        if currentVersion == lastRatedVersion && requestOnRatedVersion == false {
            return
        }

        clearStoredData()
    }
}

// MARK: - Saving state

private extension QuickReview {
    func setFirstLaunchDateIfNeeded() {
        if firstLaunchDate == nil {
            firstLaunchDate = Date()
        }
    }

    func incrementLaunchCount() {
        launchCount += 1
    }

    func storeRatedVersionDetails() {
        lastRateDate = Date()
        lastRatedVersion = currentVersion
    }

    func clearStoredData() {
        launchCount = 0
        firstLaunchDate = nil
        lastRateDate = nil
        lastRatedVersion = nil
    }
}

// MARK: - Notifications

private extension QuickReview {
    func addApplicationObservers() {
        NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(receiveValue: { [weak self] _ in
                guard let self = self else { return }
                let timeSinceActive = abs(self.resignActiveDate?.timeIntervalSince(Date()) ?? .zero)
                let isSignificantLaunch = timeSinceActive > 180
                if isSignificantLaunch {
                    self.setFirstLaunchDateIfNeeded()
                    self.incrementLaunchCount()
                }
                self.resignActiveDate = nil
            }).store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(receiveValue: { [weak self] _ in
                self?.resignActiveDate = Date()
            }).store(in: &cancellables)
    }
}
