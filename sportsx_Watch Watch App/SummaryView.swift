//
//  SummaryView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI
import HealthKit

struct SummaryMetricView: View {
    var title: String
    var value: String

    var body: some View {
        Text(title)
        Text(value)
            .font(.system(.title2, design: .rounded)
                    .lowercaseSmallCaps()
            )
            .foregroundColor(.accentColor)
        Divider()
    }
}

struct SummaryView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        if let data = workoutManager.summaryViewData {
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    SummaryMetricView(
                        title: "Total Time",
                        value: durationFormatter
                            .string(from: data.totalTime) ?? ""
                    ).accentColor(Color.yellow)
                    SummaryMetricView(title: "Avg HeartRate", value: "\(data.avgHeartRate)")
                    SummaryMetricView(title: "Total Energy", value: "\(data.totalEnergy)")
                    SummaryMetricView(title: "Avg Power", value: "\(data.avgPower)")
                    //Text("Activity Rings")
                    //ActivityRingsView(healthStore: workoutManager.healthStore)
                    //                .frame(width: 50, height: 50)
                    Button("Done") {
                        dismiss()
                    }
                }
                .scenePadding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            VStack {
                ProgressView("数据整理中...")
                Button("Done") {
                    dismiss()
                }
                //.navigationBarHidden(true)
            }
        }
    }
}

struct AuthToastView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            if workoutManager.isNeedWaitingAuth {
                ProgressView("准备中")
            } else {
                Text("请先在健康-共享-App里打开健康权限")
                Button("确认") {
                    dismiss()
                }
            }
        }
    }
}
