//
//  RunningRaceRecordManagementView.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/5.
//

import SwiftUI
import CoreLocation

struct RunningRaceRecordManagementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = RunningRaceRecordManagementViewModel()
    let globalConfig = GlobalConfig.shared
    
    @State private var firstOnAppear = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
                
                Spacer()
                
                (Text(LocalizedStringKey(SportName.Running.name)) + Text("competition.record.title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.clear)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // 选项卡
            HStack(spacing: 0) {
                ForEach(["tab.incompleted", "competition.record.status.completed"].indices, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(["tab.incompleted", "competition.record.status.completed"][index])
                            .font(.system(size: 16, weight: viewModel.selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(viewModel.selectedTab == index ? Color.white : Color.gray)
                        
                        // 选中指示器
                        Rectangle()
                            .fill(viewModel.selectedTab == index ? Color.white : Color.clear)
                            .frame(width: 80, height: 3)
                    }
                    .onTapGesture {
                        withAnimation {
                            viewModel.selectedTab = index
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 5)
            
            // 内容区域
            TabView(selection: $viewModel.selectedTab) {
                // 未完成列表
                ScrollView {
                    if viewModel.incompleteRecords.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 20) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 80)
                                
                                Text("competition.record.incompleted.no_data")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.incompleteRecords) { record in
                                RunningCompetitionRecordCard(viewModel: viewModel, record: record)
                                    .onAppear {
                                        if record == viewModel.incompleteRecords.last && viewModel.hasMoreIncompleteRecords {
                                            Task {
                                                await viewModel.queryIncompleteRecords(withLoadingToast: false, reset: false)
                                            }
                                        }
                                    }
                            }
                            if viewModel.isIncompleteLoading {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                .tag(0)
                .refreshable {
                    await viewModel.queryIncompleteRecords(withLoadingToast: false, reset: true)
                }
                
                // 已完成列表
                ScrollView {
                    if viewModel.completedRecords.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 20) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 80)
                                
                                Text("competition.record.completed.no_data")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.completedRecords) { record in
                                RunningCompetitionRecordCard(viewModel: viewModel, record: record)
                                    .onAppear {
                                        if record == viewModel.completedRecords.last && viewModel.hasMoreCompletedRecords {
                                            Task {
                                                await viewModel.queryCompletedRecords(withLoadingToast: false, reset: false)
                                            }
                                        }
                                    }
                            }
                            if viewModel.isCompletedLoading {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                .tag(1)
                .refreshable {
                    await viewModel.queryCompletedRecords(withLoadingToast: false, reset: true)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onStableAppear {
            if firstOnAppear || globalConfig.refreshRecordManageView {
                Task {
                    await viewModel.queryIncompleteRecords(withLoadingToast: true, reset: true)
                }
                Task {
                    await viewModel.queryCompletedRecords(withLoadingToast: true, reset: true)
                }
                globalConfig.refreshRecordManageView = false
            }
            DispatchQueue.main.async {
                firstOnAppear = false
            }
        }
    }
}

// 比赛记录卡片组件
struct RunningCompetitionRecordCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: RunningRaceRecordManagementViewModel
    let record: RunningRaceRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部信息：赛道名和比赛类型
            HStack(spacing: 0) {
                // 赛道名称
                Text(record.trackName)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                if record.status != .completed && record.status != .notStarted {
                    (Text(" [") + Text(LocalizedStringKey(record.status.displayName)) + Text("]"))
                        .font(.subheadline)
                        .foregroundStyle(record.status.backgroundColor)
                }
                
                Spacer()
                
                // 比赛类型标签
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(record.competitionTypeText))
                    if let teamTitle = record.teamTitle {
                        Text(":  \(teamTitle)")
                    }
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(record.isTeam ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                )
                .foregroundColor(record.isTeam ? .orange : .green)
            }
            
            Divider()
            
            // 比赛时间
            if record.status == .notStarted {
                if record.isTeam {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondText)
                        
                        let competitionEnd: Date? = {
                            guard let start = record.teamCompetitionDate,
                                  let end = record.trackEndDate else {
                                return nil
                            }
                            return min(start.addingTimeInterval(7200), end)
                        }()
                        
                        (Text("competition.begin_date.valid") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(record.teamCompetitionDate))) + Text("-") + Text(LocalizedStringKey(DateDisplay.formattedDate(competitionEnd))))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondText)
                        
                        (Text("competition.deadline") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(record.trackEndDate))))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                    }
                }
            }
            
            if record.status != .notStarted && record.status != .recording {
                // 开始时间
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                    (Text("competition.begin_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(record.startDate))))
                        .font(.subheadline)
                }
                .foregroundStyle(Color.secondText)
                
                // 如果已完成，显示完成时间
                HStack(spacing: 4) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 14))
                    (Text("competition.complete_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(record.endDate))))
                        .font(.subheadline)
                }
                .foregroundStyle(Color.secondText)
                
                // 持续时间
                if let _ = record.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 14))
                        (Text("competition.record.time") + Text(": ") + Text(TimeDisplay.formattedTime(record.duration, showFraction: true)))
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.secondText)
                }
            }
            
            // 报名时间
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                (Text("competition.register_date") + Text(": ") + Text(LocalizedStringKey(DateDisplay.formattedDate(record.createdDate))))
                    .font(.subheadline)
            }
            .foregroundStyle(Color.secondText)
            
            Divider()
            
            // 对于未完成的比赛，添加操作按钮
            if record.status == .notStarted {
                HStack(spacing: 0) {
                    (Text(LocalizedStringKey(record.regionName)) + Text(" - \(record.eventName)"))
                        .font(.caption)
                        .foregroundStyle(Color.secondText)
                    
                    Spacer()
                    
                    // 开始按钮
                    CommonTextButton(text: "competition.start") {
                        viewModel.startCompetition(record: record)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color.secondText)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(appState.competitionManager.isRecording ? Color.gray.opacity(0.5) : Color.green.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(appState.competitionManager.isRecording ? Color.gray.opacity(0.8) : Color.green.opacity(0.8), lineWidth: 1)
                            )
                            .shadow(color: appState.competitionManager.isRecording ? Color.gray.opacity(0.1) : Color.green.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                    .disabled(appState.competitionManager.isRecording)
                    
                    // 取消按钮
                    CommonTextButton(text: "action.cancel_register") {
                        PopupWindowManager.shared.presentPopup(
                            title: "action.cancel_register",
                            message: "competition.record.popup.cancel_register",
                            bottomButtons: [
                                .cancel(),
                                .confirm() {
                                    viewModel.cancelCompetition(record: record)
                                }
                            ]
                        )
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color.secondText)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.red.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.red.opacity(0.8), lineWidth: 1)
                            )
                            .shadow(color: Color.red.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                    .padding(.leading, 10)
                }
            }
            
            // 对于已完成的比赛，添加详情按钮
            if record.status != .notStarted && record.status != .recording {
                HStack {
                    (Text(LocalizedStringKey(record.regionName)) + Text(" - \(record.eventName)"))
                        .font(.caption)
                        .foregroundStyle(Color.secondText)
                    
                    Spacer()
                    
                    // 详情按钮
                    CommonTextButton(text: "action.detail") {
                        appState.navigationManager.append(.runningRecordDetailView(recordID: record.record_id))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color.secondText)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.blue.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.blue.opacity(0.8), lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                    
                    // 反馈按钮
                    /*CommonTextButton(text: "对成绩有疑问?") {
                        viewModel.feedback(record: record)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)*/
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.4))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}
