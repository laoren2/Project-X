//
//  RVRCompetitionView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/7.
//

import SwiftUI
import MapKit

// 包装器：将 CLLocationCoordinate2D 转成 Equatable
struct CoordinateWrapper: Equatable {
    let coordinate: CLLocationCoordinate2D
    
    // 手动实现 Equatable
    static func == (lhs: CoordinateWrapper, rhs: CoordinateWrapper) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct RVRCompetitionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: RVRCompetitionViewModel
    @ObservedObject var centerViewModel: SportCenterViewModel
    @ObservedObject var currencyManager = CurrencyManager.shared
    
    @State private var startLatitude: String = ""
    @State private var startLongitude: String = ""
    @State private var endLatitude: String = ""
    @State private var endLongitude: String = ""
    
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // 安全获取当前选中的赛道
    private var currentTrack: Track? {
        guard !centerViewModel.tracks.isEmpty,
              centerViewModel.selectedTrackIndex >= 0,
              centerViewModel.selectedTrackIndex < centerViewModel.tracks.count else {
            return nil
        }
        return centerViewModel.tracks[centerViewModel.selectedTrackIndex]
    }
    
    // 安全获取当前选中的比赛
    private var currentEvent: Event? {
        guard !centerViewModel.events.isEmpty,
              centerViewModel.selectedEventIndex >= 0,
              centerViewModel.selectedEventIndex < centerViewModel.events.count else {
            return nil
        }
        return centerViewModel.events[centerViewModel.selectedEventIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 赛事选择区域
            HStack {
                if !centerViewModel.events.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(centerViewModel.events) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.name)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.primary)
                                        .fontWeight(.semibold)
                                    
                                    Text(event.description)
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(centerViewModel.selectedEventIndex == event.eventIndex ?
                                              Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(centerViewModel.selectedEventIndex == event.eventIndex ?
                                                Color.blue : Color.clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        centerViewModel.switchEvent(to: event.eventIndex)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.leading, 10)
                } else {
                    Spacer()
                    Text("暂无赛事")
                        .foregroundColor(.secondary)
                        //.padding(.horizontal)
                    Spacer()
                }
                // 添加1个按钮管理我的赛事
                Button(action: {
                    appState.navigationManager.path.append("competitionManagementView")
                }) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .padding(.horizontal, 10)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 20)
            
            // 使用安全检查显示地图
            if let track = currentTrack {
                Map(interactionModes: []) {
                    Annotation("From", coordinate: track.from) {
                        Image(systemName: "location.fill")
                            .padding(5)
                    }
                    Annotation("To", coordinate: track.to) {
                        Image(systemName: "location.fill")
                            .padding(5)
                    }
                }
                .frame(height: 200)
                .padding(10)
                .shadow(radius: 2)
            } else {
                // 当没有可用赛道时显示占位视图
                VStack {
                    Text(AttributedString("无法获取赛道数据\n1.请检查 首页-广场 中的定位信息\n2.请检查应用是否取得定位权限"))
                        .foregroundColor(.secondary)
                    Image(systemName: "map")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .opacity(0.5)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .padding(10)
            }
            
            // 赛道选择
            if centerViewModel.tracks.isEmpty {
                Text("暂无可用赛道")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(centerViewModel.tracks) {track in
                            Text(track.name)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(centerViewModel.selectedTrackIndex == track.trackIndex ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .onTapGesture {
                                    withAnimation {
                                        centerViewModel.selectedTrackIndex = track.trackIndex
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 添加赛道信息
            if let track = currentTrack {
                VStack(alignment: .leading, spacing: 12) {
                    // 赛道卡片
                    VStack(alignment: .leading, spacing: 10) {
                        // 赛道标题
                        HStack {
                            Text(track.name)
                                .font(.headline)
                                .fontWeight(.bold)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // 参与人数信息
                            HStack(spacing: 5) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    //.frame(width: 24, height: 24, alignment: .center)
                                Text("总参与人数: \(track.totalParticipants > 0 ? "\(track.totalParticipants)" : "未知")")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        
                        Divider()
                        
                        // 赛道详细信息 - 使用LazyVGrid布局
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], alignment: .leading, spacing: 12) {
                            // 海拔差
                            InfoItemView(
                                iconName: "arrow.up.arrow.down", 
                                iconColor: .blue, 
                                text: "海拔差: \(track.elevationDifference > 0 ? "\(track.elevationDifference)米" : "未知")"
                            )
                            
                            // 奖金池
                            InfoItemView(
                                iconName: "dollarsign.circle", 
                                iconColor: .orange, 
                                text: "奖金池: \(track.prizePool > 0 ? "\(track.prizePool)" : "未知")"
                            )
                            
                            // 地理区域
                            InfoItemView(
                                iconName: "map", 
                                iconColor: .green, 
                                text: "覆盖区域: \(track.regionName.isEmpty ? "未知" : track.regionName)"
                            )
                            
                            // 当前参与人数
                            InfoItemView(
                                iconName: "person.2", 
                                iconColor: .purple, 
                                text: "当前参与: \(track.currentParticipants > 0 ? "\(track.currentParticipants)人" : "未知")"
                            )
                        }
                        .padding(.vertical, 6)
                        
                        Divider()
                        
                        // 按钮区
                        HStack(spacing: 12) {
                            Button(action: {
                                // 创建队伍逻辑
                                centerViewModel.createTeam(for: centerViewModel.selectedTrackIndex)
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("创建队伍")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                // 加入队伍逻辑
                                centerViewModel.joinTeam(for: centerViewModel.selectedTrackIndex)
                            }) {
                                HStack {
                                    Image(systemName: "person.3")
                                    Text("加入队伍")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
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
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
            // 报名按钮区域
            VStack {
                HStack(spacing: 20) {
                    Spacer()
                    
                    // 单人按钮
                    Button(action: {
                        if let track = currentTrack {
                            // 检查是否有足够的货币
                            if currencyManager.consume(currency: "coinB", amount: track.fee) {
                                // 添加比赛记录
                                appState.competitionManager.resetCompetitionRecord(record: CompetitionRecord(sportType: centerViewModel.selectedSport, fee: track.fee, eventName: track.eventName, trackName: track.name, trackStart: track.from, trackEnd: track.to, isTeamCompetition: false))
                                
                                appState.navigationManager.path.append("competitionCardSelectView")
                            } else {
                                // 货币不足提示
                                print("货币不足，无法报名")
                            }
                        } else {
                            print("请选择一条赛道")
                        }
                    }) {
                        ZStack {
                            let overlay = appState.competitionManager.isRecording && (!appState.competitionManager.currentCompetitionRecord.isTeamCompetition)
                            let gray = appState.competitionManager.isRecording && appState.competitionManager.currentCompetitionRecord.isTeamCompetition
                            // 按钮容器
                            RoundedRectangle(cornerRadius: 10)
                                .fill(gray ? .gray.opacity(0.5) : .yellow.opacity(0.5))
                                .frame(width: 120, height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(gray ? .gray.opacity(0.8) : Color.yellow.opacity(0.8), lineWidth: 1.5)
                                )
                                .shadow(color: Color.yellow.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            // 按钮文字
                            VStack(alignment: .center, spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person")
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    
                                    Text("报名")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .padding(.bottom, 2)
                                
                                Text("单人")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 禁用状态蒙版
                            if overlay {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.5))
                                        .frame(width: 120, height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.green.opacity(0.8), lineWidth: 1.5)
                                        )
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "figure.run")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                        
                                        Text("比赛进行中")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(appState.competitionManager.isRecording)
                    
                    Spacer()
                    
                    // 组队按钮
                    Button(action: {
                        if let track = currentTrack {
                            // 检查是否有足够的货币
                            if currencyManager.consume(currency: "coinB", amount: track.fee) {
                                //appState.competitionManager.startCoordinate = track.from
                                //appState.competitionManager.endCoordinate = track.to
                                
                                // 添加比赛记录
                                appState.competitionManager.resetCompetitionRecord(record: CompetitionRecord(sportType: centerViewModel.selectedSport, fee: track.fee, eventName: track.eventName, trackName: track.name, trackStart: track.from, trackEnd: track.to, isTeamCompetition: true))
                                
                                appState.navigationManager.path.append("competitionCardSelectView")
                            } else {
                                // 货币不足提示
                                print("货币不足，无法报名")
                            }
                        } else {
                            print("请选择一条赛道")
                        }
                    }) {
                        ZStack {
                            let gray = appState.competitionManager.isRecording && (!appState.competitionManager.currentCompetitionRecord.isTeamCompetition)
                            let overlay = appState.competitionManager.isRecording && appState.competitionManager.currentCompetitionRecord.isTeamCompetition
                            // 按钮容器
                            RoundedRectangle(cornerRadius: 10)
                                .fill(gray ? .gray.opacity(0.5) : .orange.opacity(0.5))
                                .frame(width: 120, height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(gray ? .gray.opacity(0.8) : Color.orange.opacity(0.8), lineWidth: 1.5)
                                )
                                .shadow(color: Color.orange.opacity(0.1), radius: 3, x: 0, y: 2)
                            
                            // 按钮文字
                            VStack(alignment: .center, spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.3")
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    
                                    Text("报名")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .padding(.bottom, 2)
                                
                                Text("组队")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 禁用状态蒙版
                            if overlay {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green.opacity(0.5))
                                        .frame(width: 120, height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.green.opacity(0.8), lineWidth: 1.5)
                                        )
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "figure.run")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                        
                                        Text("比赛进行中")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(appState.competitionManager.isRecording)
                    
                    Spacer()
                }
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
            }
            .padding()

            Spacer()
        }
    }
}

// 新的赛道信息项组件，保证图标和文字的一致性
struct InfoItemView: View {
    let iconName: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 15))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24, alignment: .center)
            
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
    }
}

#Preview {
    let appState = AppState()
    let rvr = RVRCompetitionViewModel()
    let center = SportCenterViewModel()
    center.fetchEventsByCity("上海市")
    return RVRCompetitionView(viewModel: rvr, centerViewModel: center)
        .environmentObject(appState)
}
