//
//  sportsx_WatchApp.swift
//  sportsx_Watch Watch App
//
//  Created by 任杰 on 2025/1/6.
//

import SwiftUI
import WatchKit
import HealthKit


class AppDelegate: NSObject, WKApplicationDelegate {
    // 当 iPhone 调用 startWatchApp() 后，系统会在这里执行这个回调
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        DispatchQueue.main.async {
            WatchDataManager.shared.startWorkout(config: workoutConfiguration)
            WatchDataManager.shared.startCollecting()
        }
    }
}

@main
struct sportsx_Watch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor var appDelegate: AppDelegate
    @StateObject var dataManager = WatchDataManager.shared
    var body: some Scene {
        WindowGroup {
            NaviView()
                .sheet(isPresented: $dataManager.showingSummaryView) {
                    SummaryView()
                }
                .onChange(of: dataManager.showingSummaryView) {
                    dataManager.summaryViewData = nil
                }
                .environmentObject(dataManager)
        }
    }
}
