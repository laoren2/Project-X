//
//  sportsx_WatchApp.swift
//  sportsx_Watch Watch App
//
//  Created by 任杰 on 2025/1/6.
//

import SwiftUI

@main
struct sportsx_Watch_Watch_AppApp: App {
    @StateObject private var dataManager = WatchDataManager()
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
