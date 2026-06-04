//
//  RouteApplicationBackendView.swift
//  sportsx
//
//  热门训练路线申请转为赛道的后台审核面板
//
#if DEBUG
import SwiftUI

struct RouteApplicationBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = RouteApplicationBackendViewModel()

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                Spacer()
                Text("路线转赛道审核")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }

            // 运动 + 状态筛选
            HStack {
                Picker("运动", selection: $viewModel.sport) {
                    Text("自行车").tag(SportName.Bike)
                    Text("跑步").tag(SportName.Running)
                }
                .pickerStyle(.segmented)

                Picker("状态", selection: $viewModel.statusFilter) {
                    Text("待审核").tag(RouteApplyStatus.pending)
                    Text("已通过").tag(RouteApplyStatus.approved)
                    Text("已驳回").tag(RouteApplyStatus.rejected)
                }
                .pickerStyle(.menu)
            }

            Button("查询申请") {
                viewModel.reset()
                viewModel.queryApplications()
            }
            .padding(.vertical, 4)

            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.applications) { application in
                        RouteApplicationCardView(viewModel: viewModel, application: application)
                            .onAppear {
                                if application == viewModel.applications.last && viewModel.hasMore {
                                    viewModel.queryApplications()
                                }
                            }
                    }
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top)
            }
            .background(.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .lightPage()
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .alert("驳回原因", isPresented: $viewModel.showRejectAlert) {
            TextField("请输入驳回原因（可选）", text: $viewModel.rejectNote)
            Button("取消", role: .cancel) {
                viewModel.rejectNote = ""
                viewModel.selectedApplication = nil
            }
            Button("确认驳回", role: .destructive) {
                if let application = viewModel.selectedApplication {
                    viewModel.review(application: application, approve: false, note: viewModel.rejectNote)
                }
                viewModel.rejectNote = ""
                viewModel.selectedApplication = nil
            }
        }
    }
}

struct RouteApplicationCardView: View {
    @ObservedObject var viewModel: RouteApplicationBackendViewModel
    let application: RouteApplicationInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(application.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if application.isPremium {
                    Text("高级")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Text("申请人：\(application.applicantNickname)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("子区域：\(application.subRegionName)（\(application.language)）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("地形：\(application.terrainType)  生命周期：\(application.lifecycle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("热度：申请时 \(application.participateCount) / 当前 \(application.currentParticipateCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: "距离：%.2f km  海拔差：%d m", application.distance, application.elevationDifference))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let note = application.reviewNote, !note.isEmpty {
                Text("备注：\(note)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let trackID = application.trackID {
                Text("赛道：\(trackID)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if application.status == "pending" {
                HStack {
                    Spacer()
                    Button("驳回") {
                        viewModel.selectedApplication = application
                        viewModel.rejectNote = ""
                        viewModel.showRejectAlert = true
                    }
                    .foregroundStyle(.red)
                    .padding(.trailing, 12)
                    Button("通过") {
                        viewModel.review(application: application, approve: true, note: nil)
                    }
                    .foregroundStyle(.green)
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Spacer()
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(application.status == "approved" ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }

    private var statusText: String {
        switch application.status {
        case "approved": return "已通过"
        case "rejected": return "已驳回"
        case "pending": return "待审核"
        default: return application.status
        }
    }
}
#endif
