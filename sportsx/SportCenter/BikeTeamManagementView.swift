//
//  BikeTeamManagementView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/24.
//

import SwiftUI

struct BikeTeamManagementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeTeamManagementViewModel()
    let globalConfig = GlobalConfig.shared
    @State private var firstOnAppear = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("bike队伍管理")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
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
                ForEach(["已创建", "已申请", "已加入"].indices, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(["已创建", "已申请", "已加入"][index])
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
                // 已创建队伍
                ScrollView {
                    if viewModel.myCreatedTeams.isEmpty {
                        emptyTeamView(title: "您还没有创建任何队伍", subtitle: "在赛事中心创建您的第一支队伍")
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.myCreatedTeams) { team in
                                BikeTeamCardView(viewModel: viewModel, type: .created, team: team)
                                    .onAppear {
                                        if team == viewModel.myCreatedTeams.last && viewModel.hasMoreCreatedTeams {
                                            Task {
                                                await viewModel.queryCreatedTeams(withLoadingToast: false, reset: false)
                                            }
                                        }
                                    }
                            }
                            if viewModel.isCreatedLoading {
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
                    await viewModel.queryCreatedTeams(withLoadingToast: false, reset: true)
                }
                
                // 已申请队伍
                ScrollView {
                    if viewModel.myAppliedTeams.isEmpty {
                        emptyTeamView(title: "您还没有申请任何队伍", subtitle: "在赛事中心申请加入感兴趣的队伍")
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.myAppliedTeams) { team in
                                BikeTeamAppliedCardView(viewModel: viewModel, team: team)
                                    .onAppear {
                                        if team == viewModel.myAppliedTeams.last && viewModel.hasMoreAppliedTeams {
                                            Task {
                                                await viewModel.queryAppliedTeams(withLoadingToast: false, reset: false)
                                            }
                                        }
                                    }
                            }
                            if viewModel.isAppliedLoading {
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
                    await viewModel.queryAppliedTeams(withLoadingToast: false, reset: true)
                }
                
                // 已加入队伍
                ScrollView {
                    if viewModel.myJoinedTeams.isEmpty {
                        emptyTeamView(title: "您还没有加入任何队伍", subtitle: "在赛事中心申请加入感兴趣的队伍")
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.myJoinedTeams) { team in
                                BikeTeamCardView(viewModel: viewModel, type: .joined, team: team)
                                    .onAppear {
                                        if team == viewModel.myJoinedTeams.last && viewModel.hasMoreJoinedTeams {
                                            Task {
                                                await viewModel.queryJoinedTeams(withLoadingToast: false, reset: false)
                                            }
                                        }
                                    }
                            }
                            if viewModel.isJoinedLoading {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                .tag(2)
                .refreshable {
                    await viewModel.queryJoinedTeams(withLoadingToast: false, reset: true)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .toolbar(.hidden, for: .navigationBar)
        .bottomSheet(isPresented: $viewModel.showDetailSheet, size: .short) {
            TeamDescriptionView(showDetailSheet: $viewModel.showDetailSheet, selectedDescription: $viewModel.selectedDescription)
        }
        .onStableAppear {
            if firstOnAppear || globalConfig.refreshTeamManageView {
                Task {
                    await viewModel.queryCreatedTeams(withLoadingToast: true, reset: true)
                }
                Task {
                    await viewModel.queryJoinedTeams(withLoadingToast: true, reset: true)
                }
                Task {
                    await viewModel.queryAppliedTeams(withLoadingToast: true, reset: true)
                }
                globalConfig.refreshTeamManageView = false
            }
            firstOnAppear = false
        }
    }
    
    // 空队伍状态视图
    private func emptyTeamView(title: String, subtitle: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.7))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .padding(.vertical, 100)
    }
}

struct BikeTeamAppliedCardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeTeamManagementViewModel
    let user = UserManager.shared
    
    let team: BikeTeamAppliedCard
    
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            // 标题和人数
            HStack {
                Text(team.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(team.member_count)/\(team.max_member_size) 人")
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
                Text("队长")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                CachedAsyncImage(
                    urlString: team.leader_avatar_url,
                    placeholder: Image(systemName: "person"),
                    errorImage: Image(systemName: "photo.badge.exclamationmark")
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .exclusiveTouchTapGesture {
                    appState.navigationManager.append(.userView(id: team.leader_id))
                }
                
                Text("\(team.leader_name)")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
            }
            
            // 比赛时间
            Text("比赛时间: \(DateDisplay.formattedDate(team.competition_date))")
                .font(.caption)
                .foregroundColor(Color.gray)
            
            // 分隔线
            Divider()
            
            Text("\(team.region_name)-\(team.event_name)-\(team.track_name)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Divider()
            
            // 底部信息
            HStack {
                Spacer()
                
                // 详情按钮
                CommonTextButton(text: "查看简介") {
                    viewModel.selectedDescription = team.description
                    viewModel.showDetailSheet = true
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .cornerRadius(8)
                
                // 取消申请按钮
                CommonTextButton(text: "取消申请") {
                    viewModel.cancelApplied(teamID: team.team_id)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .cornerRadius(8)
                
                // 申请状态
                Text("等待审核")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct BikeTeamCardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeTeamManagementViewModel
    @State var type: TeamRelationship
    let user = UserManager.shared
    let assetManager = AssetManager.shared
    
    let team: BikeTeamCard
    
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            // 标题和人数
            HStack {
                Text(team.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(team.member_count)/\(team.max_member_size) 人")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            
            Divider()
            
            // 比赛时间
            Text("比赛时间: \(DateDisplay.formattedDate(team.competition_date))")
                .font(.caption)
                .foregroundColor(Color.gray)
            
            Divider()
            
            Text("\(team.region_name)-\(team.event_name)-\(team.track_name)")
                .font(.caption)
                .foregroundColor(Color.gray)
            
            Divider()
            
            // 底部信息
            HStack {
                // 显示队伍码
                if type != .applied {
                    HStack(spacing: 4) {
                        // 显示队伍码
                        Text("队伍码: \(team.team_code)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                    }
                    .onTapGesture {
                        UIPasteboard.general.string = team.team_code
                        
                        let toast = Toast(message: "已复制: \(team.team_code)", duration: 2)
                        ToastManager.shared.show(toast: toast)
                    }
                }
                
                Spacer()
                
                // 按钮区域
                if type == .created {
                    // 管理按钮
                    CommonTextButton(text: "管理") {
                        appState.navigationManager.append(.bikeTeamManageView(teamID: team.team_id))
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
                    
                    // 解散按钮
                    CommonTextButton(text: "解散") {
                        disbandTeam()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(team.status == .prepared ? Color.red : Color.gray)
                    .cornerRadius(8)
                } else if type == .joined {
                    // 详情按钮
                    CommonTextButton(text: "详情") {
                        appState.navigationManager.append(.bikeTeamDetailView(teamID: team.team_id))
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                    
                    // 退出按钮
                    CommonTextButton(text: "退出") {
                        exitTeam()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 退出队伍
    func exitTeam() {
        guard var components = URLComponents(string: "/competition/bike/quit_team") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: team.team_id)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                Task {
                    await viewModel.queryJoinedTeams(withLoadingToast: true, reset: true)
                }
            default: break
            }
        }
    }
    
    // 解散队伍
    func disbandTeam() {
        guard var components = URLComponents(string: "/competition/bike/disband_team") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: team.team_id)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                Task {
                    await viewModel.queryCreatedTeams(withLoadingToast: true, reset: true)
                }
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                    }
                }
            default: break
            }
        }
    }
}

// 队伍详情视图（用于已加入/已申请/无关的队伍）
struct BikeTeamDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeTeamDetailViewModel()
    let teamID: String
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .exclusiveTouchTapGesture {
                        appState.navigationManager.removeLast()
                    }
                
                Spacer()
                
                Text("bike队伍详情")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let team = viewModel.teamInfo {
                        // 队伍基本信息
                        VStack(alignment: .leading, spacing: 10) {
                                Text("队伍信息")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            .padding(.bottom, 5)
                            
                            Group {
                                infoRow(title: "队伍名称", value: team.title)
                                infoRow(title: "队伍描述", value: team.description)
                                infoRow(title: "队伍码", value: team.team_code, highlight: true)
                                infoRow(title: "创建时间", value: DateDisplay.formattedDate(team.created_at))
                                infoRow(title: "比赛时间", value: DateDisplay.formattedDate(team.competition_date))
                                infoRow(title: "区域", value: team.region_name)
                                infoRow(title: "赛事", value: team.event_name)
                                infoRow(title: "赛道", value: team.track_name)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // 队伍成员列表
                        VStack(alignment: .leading, spacing: 10) {
                            Text("队伍成员 (\(team.members.count)/\(team.max_member_size))")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 5)
                            
                            ForEach(team.members) { member in
                                HStack(spacing: 10) {
                                    CachedAsyncImage(
                                        urlString: member.avatar_url,
                                        placeholder: Image(systemName: "person"),
                                        errorImage: Image(systemName: "photo.badge.exclamationmark")
                                    )
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .exclusiveTouchTapGesture {
                                        appState.navigationManager.append(.userView(id: member.user_id))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(member.nick_name)
                                            .font(.subheadline)
                                            .foregroundColor(Color.secondText)
                                        
                                        Text(DateDisplay.formattedDate(member.join_date))
                                            .font(.caption)
                                            .foregroundColor(Color.thirdText)
                                    }
                                    
                                    Spacer()
                                    
                                    if member.is_leader {
                                        Text("队长")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        Spacer()
                    } else {
                        Text("无team数据")
                            .foregroundStyle(Color.secondText)
                    }
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .background(Color.defaultBackground)
        .onFirstAppear {
            viewModel.queryTeam(with: teamID)
        }
    }
    
    // 信息行
    private func infoRow(title: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.subheadline)
                .foregroundColor(.secondText)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 3)
    }
}

// 队伍管理视图（用于已创建的队伍）
struct BikeTeamManageView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: BikeTeamManageViewModel
    
    init(teamID: String) {
        _viewModel = StateObject(wrappedValue: BikeTeamManageViewModel(teamID: teamID))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .exclusiveTouchTapGesture {
                        appState.navigationManager.removeLast()
                    }
                
                Spacer()
                
                Text("管理bike队伍")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let team = viewModel.teamInfo {
                        // 队伍基本信息
                        VStack(alignment: .leading, spacing: 10) {
                            HStack{
                                Text("队伍信息")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("编辑")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondText)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray)
                                    .cornerRadius(5)
                                    .exclusiveTouchTapGesture {
                                        guard !viewModel.is_locked else {
                                            let toast = Toast(message: "队伍已锁定")
                                            ToastManager.shared.show(toast: toast)
                                            return
                                        }
                                        viewModel.showTeamEditor = true
                                    }
                            }
                            .padding(.bottom, 5)
                            
                            Group {
                                infoRow(title: "队伍名称", value: team.title)
                                infoRow(title: "队伍描述", value: team.description)
                                infoRow(title: "队伍码", value: team.team_code)
                                infoRow(title: "创建时间", value: DateDisplay.formattedDate(team.created_at))
                                infoRow(title: "比赛时间", value: DateDisplay.formattedDate(team.competition_date))
                                infoRow(title: "区域", value: team.region_name)
                                infoRow(title: "赛事", value: team.event_name)
                                infoRow(title: "赛道", value: team.track_name)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // 队伍设置区域
                        VStack(alignment: .leading, spacing: 10) {
                            Text("队伍设置")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 5)
                            
                            // 控制队伍的公开状态
                            Toggle("公开队伍信息", isOn: Binding(
                                get: { viewModel.is_public },
                                set: { newValue in
                                    guard !viewModel.is_locked else {
                                        let toast = Toast(message: "队伍已锁定")
                                        ToastManager.shared.show(toast: toast)
                                        return
                                    }
                                    viewModel.updateTeamPublicStatus(isPublic: newValue)
                                }
                            ))
                            .foregroundStyle(Color.secondText)
                            .tint(viewModel.is_locked ? .gray : .green)
                            
                            // 控制队伍的锁定状态
                            Toggle("锁定队伍", isOn: Binding(
                                get: { viewModel.is_locked },
                                set: { newValue in
                                    guard !viewModel.is_ready else {
                                        let toast = Toast(message: "队伍处于比赛状态,无法修改")
                                        ToastManager.shared.show(toast: toast)
                                        return
                                    }
                                    viewModel.updateTeamLockStatus(isLocked: newValue)
                                }
                            ))
                            .foregroundStyle(Color.secondText)
                            .tint(viewModel.is_ready ? .gray : .green)
                            
                            // 控制队伍进入比赛状态(不可撤回)
                            Toggle("进入比赛状态", isOn: Binding(
                                get: { viewModel.is_ready },
                                set: { newValue in
                                    guard !viewModel.is_ready else {
                                        let toast = Toast(message: "队伍处于比赛状态,无法修改")
                                        ToastManager.shared.show(toast: toast)
                                        return
                                    }
                                    viewModel.updateTeamToReadyStatus()
                                }
                            ))
                            .foregroundStyle(Color.secondText)
                            .tint(viewModel.is_ready ? .gray : .green)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // 队伍成员列表
                        VStack(alignment: .leading, spacing: 10) {
                            Text("队伍成员 (\(viewModel.members.count)/\(team.max_member_size))")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.bottom, 5)
                            
                            ForEach(viewModel.members) { member in
                                HStack(spacing: 10) {
                                    CachedAsyncImage(
                                        urlString: member.avatar_url,
                                        placeholder: Image(systemName: "person"),
                                        errorImage: Image(systemName: "photo.badge.exclamationmark")
                                    )
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .exclusiveTouchTapGesture {
                                        appState.navigationManager.append(.userView(id: member.user_id))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(member.nick_name)
                                            .font(.subheadline)
                                            .foregroundColor(Color.secondText)
                                        
                                        Text(DateDisplay.formattedDate(member.join_date))
                                            .font(.caption)
                                            .foregroundColor(Color.thirdText)
                                    }
                                    
                                    Spacer()
                                    
                                    // 报名情况
                                    Text(member.is_registered ? "已报名" : "未报名")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(member.is_registered ? Color.green : Color.gray)
                                        .cornerRadius(8)
                                    
                                    if member.is_leader {
                                        Text("队长")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                    } else {
                                        Text("移除")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(!viewModel.is_locked ? Color.red : Color.gray)
                                            .cornerRadius(8)
                                            .exclusiveTouchTapGesture {
                                                viewModel.removeMember(with: member.member_id)
                                            }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        
                        // 入队申请
                        if !viewModel.request_members.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("入队申请 (\(viewModel.request_members.count))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.bottom, 5)
                                
                                ForEach(viewModel.request_members) { request in
                                    HStack(spacing: 10) {
                                        CachedAsyncImage(
                                            urlString: request.avatar_url,
                                            placeholder: Image(systemName: "person"),
                                            errorImage: Image(systemName: "photo.badge.exclamationmark")
                                        )
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            appState.navigationManager.append(.userView(id: request.user_id))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(request.nick_name)
                                                .font(.subheadline)
                                                .foregroundColor(Color.secondText)
                                            
                                            Text(DateDisplay.formattedDate(request.join_date))
                                                .font(.caption)
                                                .foregroundColor(Color.thirdText)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "ellipsis")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 18))
                                            .padding()
                                            .background(Color.gray)
                                            .clipShape(Circle())
                                            .exclusiveTouchTapGesture {
                                                viewModel.selectedAppliedMemberID = request.member_id
                                                viewModel.selectedIntroduction = request.introduction
                                                viewModel.showAppliedDetail = true
                                            }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    } else {
                        Text("无team数据")
                            .foregroundStyle(Color.secondText)
                    }
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .background(Color.defaultBackground)
        .onFirstAppear {
            viewModel.queryTeam()
        }
        .sheet(isPresented: $viewModel.showAppliedDetail) {
            BikeAppliedDetailView(viewModel: viewModel)
                .presentationDetents([.fraction(0.4)])
                .interactiveDismissDisabled()
        }
        .bottomSheet(isPresented: $viewModel.showTeamEditor, size: .large) {
            BikeTeamEditorView(viewModel: viewModel)
        }
        .onValueChange(of: viewModel.showTeamEditor) {
            if !viewModel.showTeamEditor {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    // 信息行
    private func infoRow(title: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.subheadline)
                .foregroundStyle(Color.thirdText)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 3)
    }
}

struct BikeAppliedDetailView: View {
    @ObservedObject var viewModel: BikeTeamManageViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundStyle(.clear)
                
                Spacer()
                
                Text("bike队伍描述")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    viewModel.showAppliedDetail = false
                }) {
                    Text("取消")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondText)
                }
            }
            
            ScrollView {
                Text(viewModel.selectedIntroduction ?? "暂无内容")
                    .font(.system(size: 15))
                    .foregroundColor((viewModel.selectedIntroduction != nil) ? .white : .gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(5)
            }
            .frame(height: 100)
            .padding(10)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(20)
            
            HStack {
                Spacer()
                Button(action: {
                    viewModel.rejectApplied()
                }) {
                    Text("拒绝")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                Spacer()
                Button(action: {
                    viewModel.approveApplied()
                }) {
                    Text("同意")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .background(Color.defaultBackground)
    }
}

struct BikeTeamEditorView: View {
    @ObservedObject var viewModel: BikeTeamManageViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    viewModel.showTeamEditor = false
                }) {
                    Text("取消")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondText)
                }
                
                Spacer()
                
                Text("编辑bike队伍信息")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    viewModel.saveTeamInfo()
                }) {
                    Text("保存")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white)
                }
            }
            .padding()
            
            ScrollView {
                VStack {
                    TextField(viewModel.tempTitle, text: $viewModel.tempTitle)
                        .padding()
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .onValueChange(of: viewModel.tempTitle) {
                            DispatchQueue.main.async {
                                if viewModel.tempTitle.count > 10 {
                                    viewModel.tempTitle = String(viewModel.tempTitle.prefix(10)) // 限制为最多10个字符
                                }
                            }
                        }
                    
                    HStack {
                        Text("最多输入10个字符")
                            .font(.footnote)
                            .foregroundStyle(Color.secondText)
                        
                        Spacer()
                        
                        Text("已输入\(viewModel.tempTitle.count)/10字符")
                            .font(.footnote)
                            .foregroundStyle(Color.secondText)
                    }
                    .padding(.bottom, 10)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.tempDescription)
                            .frame(maxHeight: 120)
                            .padding(16)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .onValueChange(of: viewModel.tempDescription) {
                                DispatchQueue.main.async {
                                    if viewModel.tempDescription.count > 50 {
                                        viewModel.tempDescription = String(viewModel.tempDescription.prefix(50)) // 限制为最多50个字符
                                    }
                                }
                            }
                        if viewModel.tempDescription.isEmpty {
                            Text("队伍简介（50字以内）")
                                .foregroundColor(.thirdText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        }
                    }
                    
                    HStack {
                        Text("最多输入50个字符")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                        
                        Spacer()
                        
                        Text("已输入\(viewModel.tempDescription.count)/50字符")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                    }
                    .padding(.bottom, 10)
                    
                    if let team = viewModel.teamInfo, let _ = team.competition_date, let endDate = team.track_end_date, endDate > Date() {
                        DatePicker("比赛时间", selection: $viewModel.tempDate, in: Date()...endDate)
                            .foregroundStyle(Color.secondText)
                            .tint(Color.orange)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .environment(\.colorScheme, .dark)
        .background(Color.defaultBackground)
        .hideKeyboardOnScroll()
    }
}


#Preview {
    let appState = AppState.shared
    
    return BikeTeamManagementView()
        .environmentObject(appState)
    //CompetitionRecordCard(competition: record, onStart: {}, onDelete: {}, onFeedback: {})
}
