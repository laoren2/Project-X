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
    static let videoWatermark = Logger(subsystem: subsystem, category: "video_watermark")
    
    func info_public(_ message: String) {
        info("\(message, privacy: .public)")
    }
    
    func notice_public(_ message: String) {
        notice("\(message, privacy: .public)")
    }
    
    /// 调试信息在 Release 中完全不求值，避免插值、格式化和隐私数据进入正式日志。
    func debug_public(_ message: @autoclosure () -> String) {
        #if DEBUG
        let resolvedMessage = message()
        debug("\(resolvedMessage, privacy: .public)")
        #endif
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
