//
//  Loggable.swift
//  ClearFunds
//
//  Created by Igor Fedorov on 10.03.2025.
//

import os


protocol Loggable {
    static var logger: Logger { get }
}

extension Loggable {
    static var logger: Logger {
        Logger(subsystem: "com.clearfunds.ios", category: String(describing: Self.self))
    }
}
