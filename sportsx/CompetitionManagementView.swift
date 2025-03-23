//
//  CompetitionManagementView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/7.
//

import SwiftUI
import CoreLocation

struct CompetitionManagementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CompetitionManagementViewModel()
    
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Button(action: {
                    appState.navigationManager.path.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("我的赛事")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            .padding(.top, 15)
            .padding(.bottom, 10)
            
            // 选项卡
            HStack(spacing: 0) {
                ForEach(["未完成", "已完成"].indices, id: \.self) { index in
                    Button(action: {
                        withAnimation {
                            viewModel.selectedTab = index
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(["未完成", "已完成"][index])
                                .font(.system(size: 16, weight: viewModel.selectedTab == index ? .semibold : .regular))
                                .foregroundColor(viewModel.selectedTab == index ? .blue : .gray)
                            
                            // 选中指示器
                            Rectangle()
                                .fill(viewModel.selectedTab == index ? Color.blue : Color.clear)
                                .frame(width: 80, height: 3)
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
                    if viewModel.incompleteCompetitions.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 80)
                            
                            Text("暂无未完成的比赛")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.incompleteCompetitions) { competition in
                                CompetitionRecordCard(competition: competition, onStart:  {
                                    appState.competitionManager.resetCompetitionRecord(record: competition)
                                    appState.navigationManager.path.append("competitionCardSelectView")
                                }, onDelete: {
                                    viewModel.cancelCompetition(id: competition.id)
                                })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                .tag(0)
                
                // 已完成列表
                ScrollView {
                    if viewModel.completedCompetitions.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 80)
                            
                            Text("暂无已完成的比赛")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.completedCompetitions) { competition in
                                CompetitionRecordCard(competition: competition, onFeedback: {
                                    viewModel.feedback(record: competition)
                                })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationBarHidden(true)
        .onAppear {
            // 这里可以在视图出现时进行初始化操作
            // 例如从AppState获取CompetitionManager
            viewModel.fetchCompetitionRecords()
        }
    }
}

// 比赛记录卡片组件
struct CompetitionRecordCard: View {
    let competition: CompetitionRecord
    var onStart: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onFeedback: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部信息：赛道名和比赛类型
            HStack {
                // 赛道名称
                Text(competition.eventName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: competition.sportType.iconName)
                
                Spacer()
                
                // 比赛类型标签
                Text(competition.competitionTypeText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(competition.isTeamCompetition ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    )
                    .foregroundColor(competition.isTeamCompetition ? .orange : .blue)
            }
            
            Divider()
            
            // 时间和状态信息
            HStack(alignment: .top, spacing: 8) {
                // 赛道信息
                Text(competition.trackName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 报名时间
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("报名时间: \(competition.formattedInitDate)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
                
            if competition.status == .completed {
                VStack(alignment: .leading, spacing: 8) {
                    // 开始时间
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("开始时间: \(competition.formattedStartDate)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 如果已完成，显示完成时间
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        
                        Text("完成时间: \(competition.formattedCompletionDate)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 持续时间（如果有）
                    if let _ = competition.duration {
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            Text("用时: \(competition.formattedDuration)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 得分（如果有）
                    if let score = competition.score {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            
                            Text("得分: \(String(format: "%.1f", score))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 对于未完成的比赛，添加操作按钮
            if competition.status == .incomplete {
                Divider()
                
                HStack(spacing: 0) {
                    // 报名费
                    Image(systemName: "dollarsign.circle")
                        .foregroundStyle(.yellow)
                    
                    Text("报名费:  \(competition.fee)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                    
                    Spacer()
                    
                    // 开始按钮
                    if let onStart = onStart {
                        Button(action: onStart) {
                            Text("开始比赛")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    // 取消按钮
                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Text("取消报名")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                        .padding(.leading, 10)
                    }
                }
            }
            
            // 对于已完成的比赛，只添加反馈按钮
            if competition.status == .completed {
                Divider()
                
                HStack {
                    Spacer()
                    
                    // 反馈按钮
                    if let onFeedback = onFeedback {
                        Button(action: onFeedback) {
                            Text("对成绩有疑问?")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
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

#Preview {
    let appState = AppState()
    
    // 添加一些测试数据
    let record = CompetitionRecord(sportType: .Default, fee: 55, eventName: "event", trackName: "track", trackStart: CLLocationCoordinate2D(latitude: 0, longitude: 0), trackEnd: CLLocationCoordinate2D(latitude: 1, longitude: 1), isTeamCompetition: true, status: .completed)
    
    //return CompetitionManagementView()
    //    .environmentObject(appState)
    CompetitionRecordCard(competition: record, onStart: {}, onDelete: {}, onFeedback: {})
}
