//
//  RunningTrainingRecordHistoryView.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/16.
//

import SwiftUI
import Foundation


struct RunningTrainingRecordHistoryView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @StateObject var vm = RunningTrainingRecordHistoryViewModel()

    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text("training.history.title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            CalendarHeaderView(
                monthText: vm.monthText,
                onPrev: vm.prevMonth,
                onNext: vm.nextMonth
            )
            RunningCalendarGridView(viewModel: vm)
            Rectangle()
                .foregroundStyle(Color.thirdText)
                .frame(height: 1)
                .padding()
            RunningTrainingRecordListView(records: vm.records)
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}

struct RunningCalendarGridView: View {
    @ObservedObject var viewModel: RunningTrainingRecordHistoryViewModel

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.calendarDays) { day in
                CalendarDayCell(day: day, isSelected: day.isSameDay(as: viewModel.selectedDay))
                    .onTapGesture {
                        viewModel.selectDay(day)
                    }
            }
        }
        .padding(.horizontal)
    }
}

struct RunningTrainingRecordListView: View {
    let records: [RunningFreeTrainingRecord]

    var body: some View {
        if !records.isEmpty {
            ScrollView {
                VStack {
                    ForEach(records) { record in
                        RunningTrainingRecordCardView(record: record)
                    }
                }
                .padding()
            }
        } else {
            Spacer()
            Text("training.history.no_record")
                .foregroundStyle(Color.secondary)
            Spacer()
        }
    }
}

struct RunningTrainingRecordCardView: View {
    @EnvironmentObject var appState: AppState
    let record: RunningFreeTrainingRecord
    
    var body: some View {
        HStack(spacing: 5) {
            Text(DateDisplay.formattedDate(record.endTime))
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
            Text("\(record.delta >= 0 ? "+" : "") \(record.delta)")
                .foregroundColor(record.delta >= 0 ? .orange : .red)
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.secondText)
                .exclusiveTouchTapGesture {
                    appState.navigationManager.append(.runningFreeTrainingRecordDetailView(recordID: record.record_id))
                }
        }
        .foregroundStyle(Color.white)
        .padding()
        .background(Color.gray.opacity(0.5))
        .cornerRadius(10)
    }
}
