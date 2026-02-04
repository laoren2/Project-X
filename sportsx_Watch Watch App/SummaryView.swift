//
//  SummaryView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI
import HealthKit

struct SummaryMetricView: View {
    let title: String
    let value: String
    let unit: String
    
    init(title: String, value: String, unit: String = "") {
        self.title = title
        self.value = value
        self.unit = unit
    }

    var body: some View {
        Text(LocalizedStringKey(title))
        (Text(value) + Text(LocalizedStringKey(unit)))
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
                        title: "competition.applewatch.total_time",
                        value: durationFormatter
                            .string(from: data.totalTime) ?? ""
                    )
                    .accentColor(Color.yellow)
                    SummaryMetricView(
                        title: "competition.applewatch.total_distance",
                        value: String(format: "%.2f", data.distance / 1000.0),
                        unit: "distance.km"
                    )
                    .accentColor(Color.green)
                    SummaryMetricView(
                        title: "competition.applewatch.avg_heartrate",
                        value: String(format: "%.1f", data.avgHeartRate),
                        unit: "heartrate.unit"
                    )
                    .accentColor(Color.pink)
                    SummaryMetricView(
                        title: "competition.applewatch.total_energy",
                        value: String(format: "%.1f", data.totalEnergy),
                        unit: "energy.unit"
                    )
                    .accentColor(Color.orange)
                    SummaryMetricView(
                        title: "competition.applewatch.avg_power",
                        value: String(format: "%.1f", data.avgPower),
                        unit: "power.unit"
                    )
                    .accentColor(Color.blue)
                    if let stepCadence = data.stepCadence {
                        SummaryMetricView(
                            title: "competition.applewatch.stepCadance",
                            value: String(format: "%.1f", stepCadence),
                            unit: "stepCadence.unit"
                        )
                        .accentColor(Color.red)
                    }
                    //Text("Activity Rings")
                    //ActivityRingsView(healthStore: workoutManager.healthStore)
                    //                .frame(width: 50, height: 50)
                    Button("action.close") {
                        dismiss()
                    }
                }
                .scenePadding()
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            VStack {
                ProgressView("competition.applewatch.data_processing")
                Button("action.close") {
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
                ProgressView("competition.applewatch.auth.preparing")
            } else {
                Text("competition.applewatch.auth.toast")
                Button("action.confirm") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let workout = WatchDataManager.shared
    workout.summaryViewData = SummaryViewData(
        avgHeartRate: 0,
        totalEnergy: 0,
        avgPower: 0,
        distance: 0,
        totalTime: 0,
        stepCadence: nil,
        cycleCadence: nil
    )
    return SummaryView()
        .environmentObject(workout)
}
