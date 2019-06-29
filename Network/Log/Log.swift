//
//  Log.swift
//  Infra
//
//  Created by Peter Livesey on 3/23/19.
//  Copyright © 2019 Aspen Designs. All rights reserved.
//

import Foundation

enum Log {

    static let level: Level = .verbose

    enum Level: Int {
        case none = 0
        case verbose = 3
        case info = 2
        case error = 1

        func shouldLog(_ level: Level) -> Bool {
            return level.rawValue <= self.rawValue
        }
    }

    /**
     Should be called whenever there is an unexpected error the application which indicates a coding error. These should never fire.
     */
    static func assertFailure(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        assertionFailure(message(), file: file, line: line)
        #else
        // Send to crashlytics or your server for logging
        #endif
    }

    static func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        if !condition() {
            assertFailure(message(), file: file, line: line)
        }
    }

    static func verbose(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        if level.shouldLog(.verbose) {
            print(message())
        }
    }

    static func info(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        if level.shouldLog(.info) {
            print(message())
        }
    }

    static func error(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        // Check if we should log again here as we don't want to call the autoclosure if we can avoid it
        if level.shouldLog(.error) {
            print(message())
        }
    }
}
