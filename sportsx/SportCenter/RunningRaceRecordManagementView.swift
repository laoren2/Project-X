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
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("running参赛记录")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            .background(Color(.systemBackground))
            
            // 选项卡
            HStack(spacing: 0) {
                ForEach(["未完成", "已完成"].indices, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(["未完成", "已完成"][index])
                            .font(.system(size: 16, weight: viewModel.selectedTab == index ? .semibold : .regular))
                            .foregroundColor(viewModel.selectedTab == index ? .blue : .gray)
                        
                        // 选中指示器
                        Rectangle()
                            .fill(viewModel.selectedTab == index ? Color.blue : Color.clear)
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
                                
                                Text("暂无报名记录")
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
                                
                                Text("暂无已完成的记录")
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
            firstOnAppear = false
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
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if record.status == .expired {
                    Text("(已过期)")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                if record.status == .invalid {
                    Text("(校验失败)")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // 比赛类型标签
                HStack(spacing: 4) {
                    Text("\(record.competitionTypeText)")
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
                            .foregroundColor(.gray)
                        
                        let competitionEnd: Date? = {
                            guard let start = record.teamCompetitionDate,
                                  let end = record.trackEndDate else {
                                return nil
                            }
                            return min(start.addingTimeInterval(7200), end)
                        }()
                        
                        Text("有效开始时间: \(DateDisplay.formattedDate(record.teamCompetitionDate)) - \(DateDisplay.formattedDate(competitionEnd))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("比赛截止时间: \(DateDisplay.formattedDate(record.trackEndDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if record.status == .completed || record.status == .expired || record.status == .invalid {
                // 开始时间
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("开始时间: \(DateDisplay.formattedDate(record.startDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 如果已完成，显示完成时间
                HStack(spacing: 4) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    
                    Text("完成时间: \(DateDisplay.formattedDate(record.endDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 持续时间
                if let _ = record.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("用时: \(TimeDisplay.formattedTime(record.duration, showFraction: true))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 报名时间
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text("报名时间: \(DateDisplay.formattedDate(record.createdDate))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 对于未完成的比赛，添加操作按钮
            if record.status == .notStarted {
                HStack(spacing: 0) {
                    Text("\(record.regionName)-\(record.eventName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                    
                    Spacer()
                    
                    // 开始按钮
                    CommonTextButton(text: "开始比赛") {
                        viewModel.startCompetition(record: record)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appState.competitionManager.isRecording ? .gray.opacity(0.2) : .green.opacity(0.2))
                    .foregroundColor(appState.competitionManager.isRecording ? .gray : .green)
                    .cornerRadius(4)
                    .disabled(appState.competitionManager.isRecording)
                    
                    // 取消按钮
                    CommonTextButton(text: "取消报名") {
                        viewModel.cancelCompetition(record: record)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)
                    .padding(.leading, 10)
                }
            }
            
            // 对于已完成的比赛，添加详情按钮
            if record.status == .completed || record.status == .expired || record.status == .invalid {
                HStack {
                    Text("\(record.regionName)-\(record.eventName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                    
                    Spacer()
                    
                    // 详情按钮
                    CommonTextButton(text: "详情") {
                        appState.navigationManager.append(.runningRecordDetailView(recordID: record.record_id))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                    
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
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}
