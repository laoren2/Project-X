//
//  OSLog.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/21.
//

import Foundation
import os

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let competition = Logger(subsystem: subsystem, category: "competition")
    
    func info_public(_ message: String) {
        info("\(message, privacy: .public)")
    }
    
    func notice_public(_ message: String) {
        notice("\(message, privacy: .public)")
    }
    
    func debug_public(_ message: String) {
        debug("\(message, privacy: .public)")
    }
    
    func warning_public(_ message: String) {
        warning("\(message, privacy: .public)")
    }
    
    func error_public(_ message: String) {
        error("\(message, privacy: .public)")
    }
    
    func log_public(_ message: String) {
        log("\(message, privacy: .public)")
    }
}
