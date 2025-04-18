//
//  TeamManagementView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/24.
//

import SwiftUI

struct TeamManagementView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = TeamManagementViewModel()
    
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: {
                        appState.navigationManager.path.removeLast()
                    }) {
                        //HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    //.padding(.leading, 16)
                    
                    Spacer()
                    
                    Text("队伍管理")
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
                        Button(action: {
                            withAnimation {
                                viewModel.selectedTab = index
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(["已创建", "已申请", "已加入"][index])
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
                    // 已创建队伍
                    if viewModel.myCreatedTeams.isEmpty {
                        emptyTeamView(title: "您还没有创建任何队伍", subtitle: "在赛事中心创建您的第一支队伍")
                            .tag(0)
                    } else {
                        teamListView(teams: viewModel.myCreatedTeams, type: .created)
                            .tag(0)
                    }
                    
                    // 已申请队伍
                    if viewModel.myAppliedTeams.isEmpty {
                        emptyTeamView(title: "您还没有申请任何队伍", subtitle: "在赛事中心申请加入感兴趣的队伍")
                            .tag(1)
                    } else {
                        teamListView(teams: viewModel.myAppliedTeams, type: .applied)
                            .tag(1)
                    }
                    
                    // 已加入队伍
                    if viewModel.myJoinedTeams.isEmpty {
                        emptyTeamView(title: "您还没有加入任何队伍", subtitle: "在赛事中心申请加入感兴趣的队伍")
                            .tag(2)
                    } else {
                        teamListView(teams: viewModel.myJoinedTeams, type: .joined)
                            .tag(2)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.fetchTeamInfo()
            }
            .sheet(item: $viewModel.selectedTeamDetail) { _ in
                TeamDetailView(selectedTeam: viewModel.selectedTeamDetail, type: viewModel.selectedTeamDetail?.getRelationship(for: viewModel.user.user?.userID ?? "未知") ?? .unrelated)
            }
            .sheet(item: $viewModel.selectedTeamManage) { _ in
                TeamManageView(viewModel: viewModel)
            }
            
            // 显示复制的文字提示
            if viewModel.showCopiedText {
                Text("已复制: \(viewModel.teamCode)")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(8)
                    .transition(.opacity)
                    .offset(y: -50) // 上移，防止遮挡
            }
        }
    }
    
    // 空队伍状态视图
    private func emptyTeamView(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
                .padding(.bottom, 10)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // 队伍列表视图
    private func teamListView(teams: [Team], type: TeamRelationship) -> some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(teams) { team in
                    TeamManageCard(viewModel: viewModel, type: type, team: team)
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// 队伍信息卡片
struct TeamManageCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: TeamManagementViewModel
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
            //.padding(.vertical, 30)
            
            // 底部信息
            HStack {
                // 赛事信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.eventName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(team.trackName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 显示队伍码
                    if type != .applied {
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
                            
                            viewModel.teamCode = team.teamCode
                            withAnimation {
                                viewModel.showCopiedText = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                viewModel.teamCode = ""
                                withAnimation {
                                    viewModel.showCopiedText = false
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 按钮区域
                if type == .created {
                    // 管理按钮
                    Button(action: {
                        viewModel.selectedTeamManage = team
                    }) {
                        Text("管理")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    // 解散按钮
                    Button(action: {
                        disbandTeam()
                    }) {
                        Text("解散")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(team.statusIsPrepared ? Color.red : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!team.statusIsPrepared)
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
                    
                    // 退出按钮
                    Button(action: {
                        exitTeam()
                    }) {
                        Text("退出")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(team.statusIsPrepared ? Color.red : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!team.statusIsPrepared)
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
                    
                    // 取消申请按钮
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
                    Text("等待审核")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .alert(isPresented: $viewModel.showCardAlert) {
            Alert(
                title: Text("提示"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    // 取消申请加入
    func cancelApplied() {
        if team.isPublic, let index = appState.competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }),
           let memberIndex = appState.competitionManager.availableTeams[index].pendingRequests.firstIndex(where: { $0.userID == user.user?.userID }) {
            appState.competitionManager.availableTeams[index].pendingRequests.remove(at: memberIndex)
        }
        
        if let index = viewModel.myAppliedTeams.firstIndex(where: { $0.id == team.id }) {
            viewModel.myAppliedTeams.remove(at: index)
        }
        
        if let index = appState.competitionManager.myAppliedTeams.firstIndex(where: { $0.id == team.id }) {
            appState.competitionManager.myAppliedTeams.remove(at: index)
        }
    }
    
    // 退出队伍
    func exitTeam() {
        if let me = team.members.firstIndex(where: { $0.userID == user.user?.userID }), team.members[me].isRegistered {
            viewModel.alertMessage = "请先取消报名再退出队伍"
            viewModel.showCardAlert = true
            return
        }
        
        if let index = viewModel.myJoinedTeams.firstIndex(where: { $0.id == team.id }) {
            viewModel.myJoinedTeams.remove(at: index)
        }
        
        if let index = appState.competitionManager.myJoinedTeams.firstIndex(where: { $0.id == team.id }) {
            appState.competitionManager.myJoinedTeams.remove(at: index)
        }
        
        if team.isPublic, let index = appState.competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }),
           let memberIndex = appState.competitionManager.availableTeams[index].members.firstIndex(where: { $0.userID == user.user?.userID }) {
            print("availableTeam member remove success")
            appState.competitionManager.availableTeams[index].members.remove(at: memberIndex)
        }
    }
    
    // 解散队伍
    func disbandTeam() {
        if let me = team.members.firstIndex(where: { $0.userID == user.user?.userID }), team.members[me].isRegistered {
            viewModel.alertMessage = "请先取消报名再解散队伍"
            viewModel.showCardAlert = true
            return
        }
        
        // 服务端将此队伍中的member逐个移出并返还已报名的费用，最后删除此队伍
        if let index = viewModel.myCreatedTeams.firstIndex(where: { $0.id == team.id }) {
            viewModel.myCreatedTeams.remove(at: index)
        }
        
        if let index = appState.competitionManager.myCreatedTeams.firstIndex(where: { $0.id == team.id }) {
            appState.competitionManager.myCreatedTeams.remove(at: index)
        }
        
        if team.isPublic, let index = appState.competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) {
            appState.competitionManager.availableTeams.remove(at: index)
        }
    }
}

// 队伍详情视图（用于已加入/已申请/无关的队伍）
struct TeamDetailView: View {
    //let team: Team
    @Environment(\.presentationMode) var presentationMode
    //@ObservedObject var viewModel: TeamManagementViewModel
    @State var selectedTeam: Team?
    @State var type: TeamRelationship
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let team = selectedTeam {
                        // 队伍基本信息
                        VStack(alignment: .leading, spacing: 10) {
                            Text("队伍信息")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 5)
                            
                            Group {
                                infoRow(title: "队伍名称", value: team.title)
                                infoRow(title: "队伍描述", value: team.description)
                                if type == .joined {
                                    infoRow(title: "队伍码", value: team.teamCode, highlight: true)
                                }
                                if let creationDate = team.creationDate {
                                    infoRow(title: "创建时间", value: formattedDate(creationDate))
                                } else {
                                    infoRow(title: "创建时间", value: "未知")
                                }
                                infoRow(title: "比赛时间", value: formattedDate(team.competitionDate))
                                infoRow(title: "赛事", value: team.eventName)
                                infoRow(title: "赛道", value: team.trackName)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // 队伍成员列表
                        VStack(alignment: .leading, spacing: 10) {
                            Text("队伍成员 (\(team.currentMemberCount)/\(team.maxMembers))")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 5)
                            
                            ForEach(team.members) { member in
                                HStack(spacing: 10) {
                                    Image(systemName: member.avatar)
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                        .frame(width: 30, height: 30)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(member.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Text(formattedDate(member.joinTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if member.isLeader {
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
                                
                                if member.id != team.members.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        Spacer()
                    } else {
                        Text("team数据为空")
                    }
                }
                .padding()
                .navigationBarTitle("队伍详情", displayMode: .inline)
                .navigationBarItems(trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                })
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 信息行
    private func infoRow(title: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(highlight ? .blue : .primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 3)
    }
}

// 队伍管理视图（用于已创建的队伍）
struct TeamManageView: View {
    //@Binding var team: Team
    @ObservedObject var viewModel: TeamManagementViewModel
    @Environment(\.presentationMode) var presentationMode

    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let team = viewModel.selectedTeamManage {
                        // 队伍基本信息
                        VStack(alignment: .leading, spacing: 10) {
                            Text("队伍信息")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 5)
                            
                            Group {
                                infoRow(title: "队伍名称", value: team.title)
                                infoRow(title: "队伍描述", value: team.description)
                                infoRow(title: "队伍码", value: team.teamCode, highlight: true)
                                if let creationDate = team.creationDate {
                                    infoRow(title: "创建时间", value: formattedDate(creationDate))
                                } else {
                                    infoRow(title: "创建时间", value: "未知")
                                }
                                infoRow(title: "比赛时间", value: formattedDate(team.competitionDate))
                                infoRow(title: "赛事", value: team.eventName)
                                infoRow(title: "赛道", value: team.trackName)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // 队伍设置区域
                        VStack(alignment: .leading, spacing: 10) {
                            let isDisabled = !team.statusIsPrepared
                            
                            Text("队伍设置")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 5)
                            
                            // 控制队伍的公开状态
                            Toggle("公开队伍信息", isOn: Binding(
                                get: { team.isPublic },
                                set: { newValue in
                                    viewModel.updateTeamPublicStatus(isPublic: newValue)
                                }
                            ))
                            .tint(isDisabled ? .gray : .blue)
                            .disabled(isDisabled)
                            
                            // 控制队伍的锁定状态
                            Toggle("锁定队伍", isOn: Binding(
                                get: { team.isLocked },
                                set: { newValue in
                                    viewModel.updateTeamLockStatus(isLocked: newValue)
                                }
                            ))
                            .tint(isDisabled ? .gray : .blue)
                            .disabled(isDisabled)
                            
                            // 控制队伍进入比赛状态(不可撤回)
                            Toggle("比赛状态", isOn: Binding(
                                get: { !team.statusIsPrepared },
                                set: { newValue in
                                    viewModel.updateTeamStatus()
                                }
                            ))
                            .tint(isDisabled ? .gray : .blue)
                            .disabled(isDisabled)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .alert(isPresented: $viewModel.showAlert) {
                            Alert(title: Text("进入比赛状态失败"),
                                  message: Text(viewModel.alertMessage),
                                  dismissButton: .default(Text("确定"))
                            )
                        }
                        
                        // 队伍成员列表
                        VStack(alignment: .leading, spacing: 10) {
                            Text("队伍成员 (\(team.currentMemberCount)/\(team.maxMembers))")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.bottom, 5)
                            
                            ForEach(team.members) { member in
                                HStack(spacing: 10) {
                                    Image(systemName: member.avatar)
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                        .frame(width: 30, height: 30)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(member.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Text(formattedDate(member.joinTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // 报名情况
                                    Text(member.isRegistered ? "已报名" : "未报名")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(member.isRegistered ? Color.green : Color.gray)
                                        .cornerRadius(8)
                                    
                                    if member.isLeader {
                                        Text("队长")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                    } else {
                                        Button(action: {
                                            viewModel.removeMember(memberId: member.id)
                                        }) {
                                            Text("移除")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(team.statusIsPrepared ? Color.red : Color.gray)
                                                .cornerRadius(8)
                                        }
                                        .disabled(!team.statusIsPrepared)
                                    }
                                }
                                .padding(.vertical, 6)
                                
                                if member.id != team.members.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // 入队申请
                        if !team.pendingRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("入队申请 (\(team.pendingRequests.count))")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 5)
                                
                                ForEach(team.pendingRequests) { request in
                                    HStack(spacing: 10) {
                                        Image(systemName: request.avatar)
                                            .font(.system(size: 18))
                                            .foregroundColor(.gray)
                                            .frame(width: 30, height: 30)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(request.name)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Text(formattedDate(request.joinTime))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 8) {
                                            // 拒绝按钮
                                            Button(action: {
                                                viewModel.handleMemberRequest(memberId: request.id, isApproved: false)
                                            }) {
                                                Text("拒绝")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.red)
                                                    .cornerRadius(8)
                                            }
                                            
                                            // 同意按钮
                                            Button(action: {
                                                viewModel.handleMemberRequest(memberId: request.id, isApproved: true)
                                            }) {
                                                Text("同意")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.green)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    
                                    if request.id != team.pendingRequests.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        
                        Spacer()
                    } else {
                        Text("team数据为空")
                    }
                }
                .padding()
                .navigationBarTitle("队伍管理", displayMode: .inline)
                .navigationBarItems(trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                })
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 信息行
    private func infoRow(title: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(highlight ? .blue : .primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 3)
    }
}


#Preview {
    let appState = AppState()
    
    return TeamManagementView()
        .environmentObject(appState)
    //CompetitionRecordCard(competition: record, onStart: {}, onDelete: {}, onFeedback: {})
}
