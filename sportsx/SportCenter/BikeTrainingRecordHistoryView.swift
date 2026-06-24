//
//  BikeTrainingRecordHistoryView.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/10.
//
import SwiftUI
import Foundation


struct BikeTrainingRecordHistoryView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @StateObject var vm = BikeTrainingRecordHistoryViewModel()

    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                HStack(spacing: 4) {
                    Image("bike")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text("training.history.title")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                // 未上传成功记录入口
                PendingUploadEntryButton(category: .training, sport: .Bike)
            }
            .padding(.horizontal)
            CalendarHeaderView(
                monthText: vm.monthText,
                onPrev: vm.prevMonth,
                onNext: vm.nextMonth
            )
            BikeCalendarGridView(viewModel: vm)
            Rectangle()
                .foregroundStyle(Color.thirdText)
                .frame(height: 1)
                .padding()
            BikeTrainingRecordListView(records: vm.records)
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}

struct BikeCalendarGridView: View {
    @ObservedObject var viewModel: BikeTrainingRecordHistoryViewModel

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

struct BikeTrainingRecordListView: View {
    let records: [BikeFreeTrainingRecord]

    var body: some View {
        if !records.isEmpty {
            ScrollView {
                VStack {
                    ForEach(records) { record in
                        BikeTrainingRecordCardView(record: record)
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

struct BikeTrainingRecordCardView: View {
    @EnvironmentObject var appState: AppState
    let record: BikeFreeTrainingRecord
    
    var body: some View {
        HStack(spacing: 20) {
            Image(record.trainingType == .freeTraining ? "free_training" : "route_training")
                .resizable()
                .scaledToFit()
                .frame(width: 20)
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(DateDisplay.formattedDate(record.endTime, part: .time))
            }
            .foregroundStyle(Color.secondText)
            .font(.system(size: 15))
            Spacer()
            MiniTrackView(coordinates: record.track)
                .frame(width: 56, height: 32)
            HStack(spacing: 4) {
                Image("momentum")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("\(record.delta)")
                    .foregroundStyle(record.delta >= 0 ? Color.white : Color.red)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.thirdText)
            }
        }
        .foregroundStyle(Color.white)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.3))
        )
        .exclusiveTouchTapGesture {
            let des: AppRoute = record.trainingType == .freeTraining ? .bikeFreeTrainingRecordDetailView(recordID: record.record_id) : .bikeRouteTrainingRecordDetailView(recordID: record.record_id)
            appState.navigationManager.append(des)
        }
    }
}

#Preview {
    BikeTrainingRecordHistoryView()
}
