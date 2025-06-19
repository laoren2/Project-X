//
//  BikeCompetitionView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/7.
//

import SwiftUI
import MapKit


struct BikeCompetitionView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeCompetitionViewModel()
    @ObservedObject var centerViewModel: CompetitionCenterViewModel
    @ObservedObject var currencyManager = CurrencyManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    
    @State private var selectedDetailEvent: BikeEvent? = nil
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // 位置和货币区域
                    HStack(spacing: 5) {
                        Spacer()
                        Text("X点券:\(currencyManager.coinA)")
                        Text("X币:\(currencyManager.coinB)")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    
                    // 赛事选择区域
                    HStack {
                        // 添加1个按钮管理我的队伍
                        VStack(spacing: 2) {
                            Button(action: {
                                appState.navigationManager.append(.teamManagementView)
                            }) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("队伍")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondText)
                        }
                        Spacer()
                        if viewModel.events.isEmpty {
                            Text("当前区域暂无赛事")
                                .foregroundColor(.secondText)
                                .padding()
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.events) { event in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Button(action: {
                                                selectedDetailEvent = event
                                            }) {
                                                Image(systemName: "info.circle")
                                                    .foregroundColor(Color.thirdText)
                                            }
                                            Text(event.name)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(viewModel.selectedEvent?.eventID == event.eventID ?
                                                      Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.selectedEvent?.eventID == event.eventID ?
                                                        Color.blue : Color.clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            // 防止频繁刷新
                                            if viewModel.selectedEvent?.eventID != event.eventID {
                                                withAnimation {
                                                    viewModel.switchEvent(to: event)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                            }
                        }
                        Spacer()
                        // 添加1个按钮管理我的赛事
                        VStack(spacing: 2) {
                            Button(action: {
                                appState.navigationManager.append(.recordManagementView)
                            }) {
                                Image(systemName: "list.bullet.clipboard")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("记录")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    
                    // 使用安全检查显示地图
                    ScrollView {
                        if let track = viewModel.selectedTrack {
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
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(radius: 2)
                            .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "map")
                                    .font(.system(size: 50))
                                    .foregroundColor(.thirdText)
                                    .opacity(0.5)
                                Text(AttributedString("无赛道数据\n1.请检查当前网络环境\n2.请切换位置区域重试"))
                                    .foregroundColor(.secondText)
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                        }
                    }
                    .frame(height: 200)
                    .disabled(true)
                    
                    HStack {
                        Spacer()
                        Image(systemName: chevronDirection2 ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .contentShape(Rectangle()) // 将整个 HStack 设为可点击区域
                    .onTapGesture {
                        chevronDirection2.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation {
                                chevronDirection.toggle()
                            }
                        }
                    }
                    .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    
                    // 赛道选择
                    if viewModel.tracks.isEmpty {
                        Text("当前赛事暂无可用赛道")
                            .foregroundColor(.secondText)
                            .padding()
                            .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.tracks) { track in
                                    Text(track.name)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                        .font(.system(size: 15))
                                        .foregroundStyle(viewModel.selectedTrack?.trackID == track.trackID ? .white : .thirdText)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(viewModel.selectedTrack?.trackID == track.trackID ?
                                                      Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(viewModel.selectedTrack?.trackID == track.trackID ?
                                                        Color.blue : Color.clear, lineWidth: 1)
                                        )
                                        .onTapGesture {
                                            // 防止频繁刷新
                                            if viewModel.selectedTrack?.trackID != track.trackID {
                                                withAnimation {
                                                    viewModel.switchTrack(to: track)
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 1)
                        }
                        .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    }
                    
                    // 添加赛道信息
                    if let track = viewModel.selectedTrack {
                        VStack(alignment: .leading, spacing: 12) {
                            // 赛道卡片
                            VStack(alignment: .leading, spacing: 10) {
                                // 赛道标题
                                HStack {
                                    Text(track.name)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // 参与人数信息
                                    HStack(spacing: 5) {
                                        Image(systemName: "person.2")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondText)
                                        //.frame(width: 24, height: 24, alignment: .center)
                                        Text("总参与人数: \(track.totalParticipants)")
                                            .font(.caption)
                                            .foregroundColor(.secondText)
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
                                        text: "海拔差: \(track.elevationDifference)"
                                    )
                                    // 奖金池
                                    InfoItemView(
                                        iconName: "dollarsign.circle",
                                        iconColor: .orange,
                                        text: "奖金池: \(track.prizePool)"
                                    )
                                    // 地理区域
                                    InfoItemView(
                                        iconName: "map",
                                        iconColor: .green,
                                        text: "覆盖区域: \(track.regionName)"
                                    )
                                    // 当前参与人数
                                    InfoItemView(
                                        iconName: "person.2",
                                        iconColor: .purple,
                                        text: "当前参与: \(track.currentParticipants)"
                                    )
                                }
                                .padding(.vertical, 6)
                                
                                Divider()
                                
                                // 按钮区
                                HStack(spacing: 12) {
                                    Button(action: {
                                        // 创建队伍逻辑
                                        viewModel.createTeam()
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
                                    .sheet(isPresented: $viewModel.showCreateTeamSheet) {
                                        TeamCreateView(viewModel: viewModel)
                                    }
                                    
                                    Button(action: {
                                        // 加入队伍逻辑
                                        viewModel.showJoinTeamSheet = true
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
                                    .sheet(isPresented: $viewModel.showJoinTeamSheet) {
                                        TeamJoinView(viewModel: viewModel)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                        .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
                    }
                }
                .padding(.horizontal, 10)
            }
            
            // 报名按钮区域
            HStack(spacing: 0) {
                Spacer()
                Text("立即报名")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 25)
                Spacer()
                // 单人按钮
                Button(action: {
                    if let track = viewModel.selectedTrack {
                        // 检查是否有足够的货币
                        if currencyManager.consume(currency: "coinB", amount: track.fee) {
                            singleRegister()
                        } else {
                            // 货币不足提示
                            viewModel.alertMessage = "货币不足，无法报名"
                            viewModel.showAlert = true
                        }
                    } else {
                        let toast = Toast(message: "请选择一条赛道")
                        ToastManager.shared.show(toast: toast)
                    }
                }) {
                    ZStack {
                        let overlay = appState.competitionManager.isRecording && (!(appState.competitionManager.currentCompetitionRecord?.isTeamCompetition ?? true))
                        let gray = appState.competitionManager.isRecording && (appState.competitionManager.currentCompetitionRecord?.isTeamCompetition ?? false)
                        // 按钮容器
                        RoundedRectangle(cornerRadius: 10)
                            .fill(gray ? .gray.opacity(0.5) : .yellow.opacity(0.5))
                            .frame(width: 80, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(gray ? .gray.opacity(0.8) : Color.yellow.opacity(0.8), lineWidth: 1.5)
                            )
                            .shadow(color: Color.yellow.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        // 按钮文字
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "person")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            
                            Text("单人")
                                .font(.subheadline)
                                .foregroundColor(.secondText)
                        }
                        
                        // 禁用状态蒙版
                        if overlay {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green.opacity(0.5))
                                    .frame(width: 80, height: 40)
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
                .alert(isPresented: $viewModel.showSingleRegisterAlert) {
                    Alert(
                        title: Text("报名成功"),
                        message: Text("单人模式"),
                        primaryButton: .default(Text("稍后开始")),
                        secondaryButton: .default(Text("立即开始")) {
                            if viewModel.selectedTrack != nil, !appState.competitionManager.isRecording, let record = viewModel.currentRecord {
                                appState.competitionManager.resetCompetitionRecord(record: record)
                                appState.navigationManager.append(.competitionCardSelectView)
                                viewModel.currentRecord = nil
                            }
                        }
                    )
                }
                
                Spacer()
                
                // 组队按钮
                Button(action: {
                    if viewModel.selectedTrack != nil {
                        viewModel.showTeamCodeSheet = true
                    } else {
                        let toast = Toast(message: "请选择一条赛道")
                        ToastManager.shared.show(toast: toast)
                    }
                }) {
                    ZStack {
                        let gray = appState.competitionManager.isRecording && (!(appState.competitionManager.currentCompetitionRecord?.isTeamCompetition ?? true))
                        let overlay = appState.competitionManager.isRecording && (appState.competitionManager.currentCompetitionRecord?.isTeamCompetition ?? false)
                        // 按钮容器
                        RoundedRectangle(cornerRadius: 10)
                            .fill(gray ? .gray.opacity(0.5) : .orange.opacity(0.5))
                            .frame(width: 80, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(gray ? .gray.opacity(0.8) : Color.orange.opacity(0.8), lineWidth: 1.5)
                            )
                            .shadow(color: Color.orange.opacity(0.1), radius: 3, x: 0, y: 2)
                        
                        // 按钮文字
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "person.3")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            
                            Text("组队")
                                .font(.subheadline)
                                .foregroundColor(.secondText)
                        }
                        
                        // 禁用状态蒙版
                        if overlay {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green.opacity(0.5))
                                    .frame(width: 80, height: 40)
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
                .sheet(isPresented: $viewModel.showTeamCodeSheet) {
                    TeamCodeView(viewModel: viewModel)
                        .presentationDetents([.fraction(0.4)])
                        .interactiveDismissDisabled() // 防止点击过快导致弹窗高度错误
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $selectedDetailEvent) { event in
            EventDetailView(event: event)
        }
        .onChange(of: locationManager.region) {
            viewModel.fetchEvents(with: locationManager.region)
        }
        .onFirstAppear {
            viewModel.fetchEvents(with: locationManager.region)
        }
    }
    
    // 单人报名
    func singleRegister() {
        // 添加比赛记录
        if let track = viewModel.selectedTrack, let event = viewModel.selectedEvent {
            let record = CompetitionRecord(sportType: appState.sport, fee: track.fee, eventName: event.name, trackName: track.name, trackStart: track.from, trackEnd: track.to, isTeamCompetition: false)
            let exists = appState.competitionManager.competitionRecords.contains { $0.id == record.id && $0.status == record.status }
            if !exists {
                appState.competitionManager.competitionRecords.append(record)
            }
            viewModel.currentRecord = record
        }
        viewModel.showSingleRegisterAlert = true
    }
}

struct EventDetailView: View {
    let event: BikeEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 背景图片
                    CachedAsyncImage(
                        urlString: event.image_url,
                        placeholder: Image("Ads"),
                        errorImage: Image(systemName: "photo.badge.exclamationmark")
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 比赛名称
                        Text(event.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        // 比赛时间
                        HStack {
                            Image(systemName: "calendar")
                            Text("\(event.startDate) - \(event.endDate)")
                                .foregroundColor(.secondary)
                        }
                        
                        // 比赛规则
                        VStack(alignment: .leading, spacing: 8) {
                            Text("比赛规则")
                                .font(.headline)
                            Text(event.description)
                                .font(.subheadline)
                            Text("1. 参赛者需在指定时间内完成比赛\n2. 比赛过程中需遵守交通规则\n3. 成绩以完成时间计算\n4. 禁止使用任何交通工具\n5. 需全程开启运动记录")
                                .foregroundColor(.secondary)
                        }
                        
                        // 赛道信息
                        VStack(alignment: .leading, spacing: 8) {
                            Text("赛道信息")
                                .font(.headline)
                            
                            ForEach(event.tracks) { track in
                                HStack {
                                    Image(systemName: "figure.run")
                                    Text(track.name)
                                    Spacer()
                                    Text("\(track.from.latitude), \(track.from.longitude) → \(track.to.latitude), \(track.to.longitude)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 赛道信息项组件
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
                .foregroundColor(.secondText)
        }
    }
}

// 组队报名页面
struct TeamCodeView: View {
    @EnvironmentObject var appState: AppState
    //@ObservedObject var centerViewModel: SportCenterViewModel
    @ObservedObject var viewModel: BikeCompetitionViewModel
    @ObservedObject var currencyManager = CurrencyManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State var teamCode: String = ""
    
    let user = UserManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 队伍码输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("请输入队伍码")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("6位队伍码", text: $teamCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .keyboardType(.asciiCapable)
                }
                .padding(.horizontal)
                
                // 提交按钮
                Button(action: {
                    if let track = viewModel.selectedTrack {
                        if registerWithTeamCode() {
                            // 检查是否有足够的货币
                            if currencyManager.consume(currency: "coinB", amount: track.fee) {
                                handleRegister()
                            } else {
                                viewModel.alertMessage = "货币不足，无法报名"
                                viewModel.teamRegisterSuccessAlert = false
                                viewModel.showAlert = true
                            }
                        } else {
                            viewModel.teamRegisterSuccessAlert = false
                            viewModel.showAlert = true
                        }
                    }
                }) {
                    Text("提交")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("输入队伍码")
            .navigationBarItems(
                trailing: Button("取消") {
                    viewModel.showTeamCodeSheet = false
                }
            )
            .alert(isPresented: $viewModel.showAlert) {
                if viewModel.teamRegisterSuccessAlert {
                    return Alert(
                        title: Text("报名成功"),
                        message: Text("组队模式"),
                        primaryButton: .default(Text("去看看")) {
                            viewModel.showTeamCodeSheet = false
                            appState.navigationManager.append(.recordManagementView)
                        },
                        secondaryButton: .default(Text("确定")) {
                            viewModel.showTeamCodeSheet = false
                        }
                    )
                } else {
                    return Alert(
                        title: Text("提示"),
                        message: Text(viewModel.alertMessage),
                        dismissButton: .default(Text("确定"))
                    )
                }
            }
        }
    }
    
    // 使用队伍码报名
    func registerWithTeamCode() -> Bool {
        guard !teamCode.isEmpty else {
            viewModel.alertMessage = "请输入队伍码"
            return false
        }
        
        if teamCode.count != 6 {
            viewModel.alertMessage = "请输入合法的6位队伍码"
            return false
        }
        
        if !viewModel.verifyTrack() {
            viewModel.alertMessage = "所选赛道内没有此队伍"
            return false
        }
        
        if !viewModel.verifyInTeam(teamCode: teamCode) {
            viewModel.alertMessage = "您不在此队伍中"
            return false
        }
        
        if viewModel.verifyRepeatRegister(teamCode: teamCode) {
            viewModel.alertMessage = "您已在此队伍中报名成功，无需重复报名"
            return false
        }
        
        return true
    }
    
    // 处理组队报名成功的逻辑
    func handleRegister() {
        // 修改队伍内用户的报名状态
        if let indexCreated = appState.competitionManager.myCreatedTeams.firstIndex(where: {$0.teamCode == teamCode}) {
            if let userIndex = appState.competitionManager.myCreatedTeams[indexCreated].members.firstIndex(where: {$0.userID == user.user.userID}) {
                appState.competitionManager.myCreatedTeams[indexCreated].members[userIndex].isRegistered = true
            }
        }
        if let indexJoined = appState.competitionManager.myJoinedTeams.firstIndex(where: {$0.teamCode == teamCode}) {
            if let userIndex = appState.competitionManager.myJoinedTeams[indexJoined].members.firstIndex(where: {$0.userID == user.user.userID}) {
                appState.competitionManager.myJoinedTeams[indexJoined].members[userIndex].isRegistered = true
            }
        }
        
        // 添加比赛记录
        if let track = viewModel.selectedTrack, let event = viewModel.selectedEvent {
            let record = CompetitionRecord(sportType: appState.sport, fee: track.fee, eventName: event.name, trackName: track.name, trackStart: track.from, trackEnd: track.to, isTeamCompetition: true, teamCode: teamCode)
            let exists = appState.competitionManager.competitionRecords.contains { $0.id == record.id && $0.status == record.status }
            if !exists {
                appState.competitionManager.competitionRecords.append(record)
            }
        }
        
        // 显示成功提示框
        viewModel.teamRegisterSuccessAlert = true
        viewModel.showAlert = true
    }
}

// 创建队伍页面
struct TeamCreateView: View {
    @ObservedObject var viewModel: BikeCompetitionViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                // 队伍名称
                Section(header: Text("基本信息")) {
                    TextField("队伍名称", text: $viewModel.teamTitle)
                    
                    TextEditor(text: $viewModel.teamDescription)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if viewModel.teamDescription.isEmpty {
                                    Text("队伍描述")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 5)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                // 队伍设置
                Section(header: Text("队伍设置")) {
                    Stepper("队伍人数: \(viewModel.teamSize)人", value: $viewModel.teamSize, in: 2...10)
                    
                    DatePicker("比赛时间", selection: $viewModel.teamCompetitionDate, in: Date()...Date().addingTimeInterval(86400 * 30))
                    
                    // 添加一个开关允许用户选择是否公开队伍信息，开关直接控制viewModel.isPublic
                    Toggle("公开队伍信息", isOn: $viewModel.isPublic)
                        .tint(.blue)
                }
                
                // 提交按钮
                Section {
                    Button(action: {
                        if viewModel.teamTitle.isEmpty {
                            viewModel.alertMessage = "请输入队伍名称"
                            viewModel.showAlert = true
                            return
                        }
                        
                        viewModel.submitCreateTeamForm()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("创建队伍")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("创建队伍")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
}

// 加入队伍页面
struct TeamJoinView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeCompetitionViewModel
    @Environment(\.presentationMode) var presentationMode
    @State var teamCode: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.clear)
                }
                
                Spacer()
                
                Text("加入队伍")
                    .font(.title)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    viewModel.showJoinTeamSheet = false
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .background(Color(.systemGroupedBackground))
            
            // 队伍码输入区域
            HStack {
                TextField("输入6位队伍码直接加入", text: $teamCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .keyboardType(.asciiCapable)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    if JoinWithTeamCode() {
                        joinTeam(teamCode: teamCode)
                    } else {
                        viewModel.showAlert = true
                    }
                }) {
                    Text("一键加入")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 15)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.vertical, 10)
                .padding(.horizontal)
            }
            .background(.blue.opacity(0.2))
            
            if viewModel.availableTeams.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.bottom, 10)
                    
                    Text("暂无可加入的队伍")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("当前赛道还没有可加入的队伍，您可以创建一个新队伍")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(viewModel.availableTeams) { team in
                            TeamPublicCard(
                                viewModel: viewModel,
                                type: team.getRelationship(for: viewModel.user.user.userID),
                                team: team
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .sheet(item: $viewModel.selectedTeamDetail) { _ in
            TeamDetailView(selectedTeam: viewModel.selectedTeamDetail, type: viewModel.selectedTeamDetail?.getRelationship(for: viewModel.user.user.userID) ?? .unrelated)
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("提示"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear {
            viewModel.fetchAvailableTeams()
        }
        .onDisappear {
            viewModel.availableTeams = []
        }
    }
    
    func JoinWithTeamCode() -> Bool {
        guard !teamCode.isEmpty else {
            viewModel.alertMessage = "请输入队伍码"
            return false
        }
        
        if teamCode.count != 6 {
            viewModel.alertMessage = "请输入合法的6位队伍码"
            return false
        }
        
        // 检查队伍是否存在
        if !viewModel.verifyTeamCode(teamCode: teamCode) {
            viewModel.alertMessage = "找不到队伍，请输入正确的队伍码"
            return false
        }
        
        // 检查是否已经在队伍中
        if viewModel.verifyInTeam(teamCode: teamCode) {
            viewModel.alertMessage = "您已在此队伍中"
            return false
        }
        
        // 检查是否处于锁定状态
        if viewModel.verifyTeamLocked(teamCode: teamCode) {
            viewModel.alertMessage = "队伍已锁定，无法加入"
            return false
        }
        
        return true
    }
    
    // 直接通过队伍码加入队伍
    func joinTeam(teamCode: String) {
        // 清空输入框
        self.teamCode = ""
        
        // 修改服务端的team数据然后拉取更新viewModel.availableTeams
        let newMember = TeamMember(
            userID: viewModel.user.user.userID,
            name: viewModel.user.user.nickname,
            avatar: viewModel.user.user.avatarImageURL,
            isLeader: false,
            joinTime: Date(),
            isRegistered: false
        )

        if let index = appState.competitionManager.myAppliedTeams.firstIndex(where: { $0.teamCode == teamCode }), let member = appState.competitionManager.myAppliedTeams[index].pendingRequests.firstIndex(where: { $0.userID == viewModel.user.user.userID }) {
            let copyMember = appState.competitionManager.myAppliedTeams[index].pendingRequests[member]
            appState.competitionManager.myAppliedTeams[index].pendingRequests.remove(at: member)
            appState.competitionManager.myAppliedTeams[index].members.append(copyMember)
            let copyTeam = appState.competitionManager.myAppliedTeams[index]
            appState.competitionManager.myAppliedTeams.remove(at: index)
            appState.competitionManager.myJoinedTeams.append(copyTeam)
        } else {
            if let index = appState.competitionManager.availableTeams.firstIndex(where: { $0.teamCode == teamCode }) {
                var copyTeam = appState.competitionManager.availableTeams[index]
                copyTeam.members.append(newMember)
                appState.competitionManager.myJoinedTeams.append(copyTeam)
            }
        }
        
        if let index = appState.competitionManager.availableTeams.firstIndex(where: { $0.teamCode == teamCode }) {
            if let member = appState.competitionManager.availableTeams[index].pendingRequests.firstIndex(where: { $0.userID == viewModel.user.user.userID }) {
                let copyMember = appState.competitionManager.availableTeams[index].pendingRequests[member]
                appState.competitionManager.availableTeams[index].pendingRequests.remove(at: member)
                appState.competitionManager.availableTeams[index].members.append(copyMember)
            } else {
                appState.competitionManager.availableTeams[index].members.append(newMember)
            }
        }
        
        if let index = viewModel.availableTeams.firstIndex(where: { $0.teamCode == teamCode }) {
            if let member = viewModel.availableTeams[index].pendingRequests.firstIndex(where: { $0.userID == viewModel.user.user.userID }) {
                let copyMember = viewModel.availableTeams[index].pendingRequests[member]
                viewModel.availableTeams[index].pendingRequests.remove(at: member)
                viewModel.availableTeams[index].members.append(copyMember)
            } else {
                viewModel.availableTeams[index].members.append(newMember)
            }
        }
        
        // 显示成功提示
        viewModel.alertMessage = "加入队伍成功"
        viewModel.showAlert = true
    }
}

struct TeamPublicCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeCompetitionViewModel
    @State var type: TeamRelationship

    
    let team: Team
    let user = UserManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和人数
            HStack {
                Text(team.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(team.currentMemberCount)/\(team.maxMembers) 人")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            
            // 队长信息
            HStack(spacing: 8) {
                Image(systemName: team.captainAvatar)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Text("队长: \(team.captainName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 描述
            Text(team.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.top, 2)
            
            // 分隔线
            Divider()
                .padding(.vertical, 6)
            
            // 底部信息
            HStack {
                if type == .created || type == .joined {
                    HStack(spacing: 4) {
                        // 显示队伍码
                        Text("队伍码: \(team.teamCode)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                    }
                    .onTapGesture {
                        UIPasteboard.general.string = team.teamCode
                        
                        let toast = Toast(message: "已复制: \(team.teamCode)", duration: 2)
                        ToastManager.shared.show(toast: toast)
                    }
                }
                
                Spacer()
                
                // 按钮区域
                if type == .created {
                    Text("我的队伍")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                } else if type == .joined {
                    // 详情按钮
                    Button(action: {
                        viewModel.selectedTeamDetail = team
                    }) {
                        Text("详情")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    
                    Text("已加入")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                        )
                } else if type == .applied {
                    // 详情按钮
                    Button(action: {
                        viewModel.selectedTeamDetail = team
                    }) {
                        Text("详情")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    
                    // "取消申请"按钮
                    Button(action: {
                        cancelApplied()
                    }) {
                        Text("取消申请")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    
                    // 申请状态
                    Text("申请中")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    // 详情按钮
                    Button(action: {
                        viewModel.selectedTeamDetail = team
                    }) {
                        Text("详情")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    
                    // 申请加入按钮
                    Button(action: {
                        applyToJoinTeam()
                    }) {
                        Text("申请加入")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 申请加入队伍
    func applyToJoinTeam() {
        if team.isLocked {
            viewModel.alertMessage = "队伍已锁定，无法申请加入"
            viewModel.showAlert = true
            return
        }
        
        type = .applied
        
        // 添加申请
        let newMember = TeamMember(
            userID: user.user.userID,
            name: user.user.nickname,
            avatar: user.user.avatarImageURL,
            isLeader: false,
            joinTime: Date(),
            isRegistered: false
        )
        
        // 在实际应用中，这里应该向服务器发起请求
        // 模拟添加申请
        var teamCopy = team
        teamCopy.pendingRequests.append(newMember)
        
        // 添加到我申请的队伍列表
        if !appState.competitionManager.myAppliedTeams.contains(where: { $0.id == team.id }) {
            appState.competitionManager.myAppliedTeams.append(teamCopy)
        }
        
        if let index = appState.competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) {
            appState.competitionManager.availableTeams[index].pendingRequests.append(newMember)
        }
        
        if let index = viewModel.availableTeams.firstIndex(where: { $0.id == team.id }) {
            viewModel.availableTeams[index].pendingRequests.append(newMember)
        }
    }
    
    // 取消申请加入
    func cancelApplied() {
        type = .unrelated
        
        if let index = viewModel.availableTeams.firstIndex(where: { $0.id == team.id }),
           let memberIndex = viewModel.availableTeams[index].pendingRequests.firstIndex(where: { $0.userID == user.user.userID }) {
            viewModel.availableTeams[index].pendingRequests.remove(at: memberIndex)
        }
        
        if let index = appState.competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }),
           let memberIndex = appState.competitionManager.availableTeams[index].pendingRequests.firstIndex(where: { $0.userID == user.user.userID }) {
            appState.competitionManager.availableTeams[index].pendingRequests.remove(at: memberIndex)
        }
        
        if let index = appState.competitionManager.myAppliedTeams.firstIndex(where: { $0.id == team.id }) {
            appState.competitionManager.myAppliedTeams.remove(at: index)
        }
    }
}

#Preview {
    let appState = AppState.shared
    //let rvr = RVRCompetitionViewModel()
    let center = CompetitionCenterViewModel()
    //rvr.fetchEventsByCity("上海市")
    return BikeCompetitionView(centerViewModel: center)
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}
