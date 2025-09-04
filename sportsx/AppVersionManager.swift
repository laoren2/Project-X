//
//  AppVersionManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/13.
//

import Foundation


struct AppVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    
    init(_ versionString: String) {
        let parts = versionString.split(separator: ".").map { Int($0) ?? 0 }
        self.major = parts.count > 0 ? parts[0] : 0
        self.minor = parts.count > 1 ? parts[1] : 0
        self.patch = parts.count > 2 ? parts[2] : 0
    }
    
    func toString() -> String {
        return "\(major).\(minor).\(patch)"
    }
    
    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

class AppVersionManager {
    static let shared = AppVersionManager()
    private(set) var currentVersion: AppVersion
    
    private init() {
        let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        currentVersion = AppVersion(versionString)
    }
    
    func checkMinimumVersion(_ minVersion: AppVersion) -> Bool {
        return currentVersion >= minVersion
    }
}
