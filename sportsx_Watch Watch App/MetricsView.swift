//
//  MetricsView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI

struct MetricsView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
    private struct MetricsTimelineSchedule: TimelineSchedule {
        var startDate: Date

        init(from startDate: Date) {
            self.startDate = startDate
        }

        func entries(from startDate: Date, mode: TimelineScheduleMode) -> PeriodicTimelineSchedule.Entries {
            PeriodicTimelineSchedule(
                from: self.startDate,
                by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0)
            ).entries(
                from: startDate,
                mode: mode
            )
        }
    }
    
    var body: some View {
        TimelineView(
            MetricsTimelineSchedule(
                from: workoutManager.builder?.startDate ?? Date()
            )
        ) { context in
            VStack(alignment: .leading) {
                ElapsedTimeView(
                    elapsedTime: workoutManager.builder?.elapsedTime ?? 0,
                    showSubseconds: !isLuminanceReduced
                ).foregroundColor(Color.yellow)
                Text(
                    workoutManager.heartRate
                        .formatted(
                            .number.precision(.fractionLength(0))
                        )
                    + " BPM"
                )
            }
            .font(.system(.title, design: .rounded)
                .monospacedDigit()
                .lowercaseSmallCaps()
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
            .scenePadding()
        }
    }
}

#Preview {
    MetricsView()
}
