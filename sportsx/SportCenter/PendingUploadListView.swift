//
//  PendingUploadListView.swift
//  sportsx
//
//  未上传成功的运动记录列表：展示本地缓存的待上传数据，支持手动重新上传 / 删除。
//  入口位于比赛记录页（RaceRecordManagementView）与训练历史页（TrainingRecordHistoryView）右上角。
//
//  Created by Claude on 2026/6/15.
//

import SwiftUI


class PendingUploadListViewModel: ObservableObject {
    @Published var uploads: [PendingWorkoutUpload] = []

    let category: PendingUploadCategory
    let sport: SportName

    private var userID: String { UserManager.shared.user.userID }

    init(category: PendingUploadCategory, sport: SportName) {
        self.category = category
        self.sport = sport
    }

    func load() {
        uploads = PendingUploadManager.shared.loadAll(userID: userID, category: category, sport: sport)
    }

    func retry(_ upload: PendingWorkoutUpload) {
        PendingUploadManager.shared.retry(upload) { [weak self] success in
            guard let self else { return }
            // retry 的 completion 已切回主线程
            guard success else { return }   // 失败时 NetworkService 已弹错误 toast，保留条目
            ToastManager.shared.show(toast: Toast(message: "upload.pending.reupload_success", duration: 2))
            self.uploads.removeAll { $0.id == upload.id }
            // 通知记录页 / 训练历史页刷新
            GlobalConfig.shared.refreshRecordManageView = true
            GlobalConfig.shared.refreshFreeTrainingView = true
            GlobalConfig.shared.refreshFamiliarity = true
        }
    }

    func delete(_ upload: PendingWorkoutUpload) {
        PendingUploadManager.shared.remove(id: upload.id, userID: userID)
        uploads.removeAll { $0.id == upload.id }
    }
}


struct PendingUploadListView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @StateObject private var vm: PendingUploadListViewModel

    init(category: PendingUploadCategory, sport: SportName) {
        _vm = StateObject(wrappedValue: PendingUploadListViewModel(category: category, sport: sport))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)

                Spacer()

                HStack(spacing: 4) {
                    Image(vm.sport.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text("upload.pending.title")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                }

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

            if vm.uploads.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image("no_data")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                    Text("upload.pending.empty")
                        .font(.headline)
                        .foregroundStyle(Color.secondText)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(vm.uploads) { upload in
                            PendingUploadCard(
                                upload: upload,
                                onReupload: { vm.retry(upload) },
                                onDelete: {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "upload.pending.delete",
                                        message: "upload.pending.delete_confirm",
                                        bottomButtons: [
                                            .cancel(),
                                            .confirm() { vm.delete(upload) }
                                        ]
                                    )
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onAppear {
            vm.load()
        }
    }
}


// 单条待上传记录卡片
struct PendingUploadCard: View {
    let upload: PendingWorkoutUpload
    let onReupload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部：模式 + 赛道/路线名
            HStack(spacing: 8) {
                Image(upload.mode.displayIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text(LocalizedStringKey(upload.mode.displayNameKey))
                    .font(.headline)
                    .foregroundStyle(Color.white)
                if let title = upload.title, !title.isEmpty {
                    Text("· \(title)")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondText)
                        .lineLimit(1)
                }
                Spacer()
            }

            Divider()

            // 结束时间
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                Text(DateDisplay.formattedDate(upload.createdAt))
                    .font(.subheadline)
            }
            .foregroundStyle(Color.secondText)

            // 距离 + 时长
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image("total_distance")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18)
                    (Text(String(format: "%.2f ", upload.distanceMeters / 1000.0)) + Text("distance.km"))
                        .font(.subheadline)
                }
                HStack(spacing: 4) {
                    Image("total_time")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18)
                    Text(TimeDisplay.formattedTime(upload.duration))
                        .font(.subheadline)
                }
                Spacer()
            }
            .foregroundStyle(Color.secondText)

            Divider()

            // 操作按钮
            HStack {
                Spacer()

                CommonTextButton(text: "upload.pending.delete") {
                    onDelete()
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
                )

                CommonTextButton(text: "upload.pending.reupload") {
                    onReupload()
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(Color.secondText)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.green.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.green.opacity(0.8), lineWidth: 1)
                        )
                )
                .padding(.leading, 10)
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


// 记录页 / 历史页右上角的待上传入口按钮（带角标）
struct PendingUploadEntryButton: View {
    let category: PendingUploadCategory
    let sport: SportName

    @ObservedObject var navigationManager = NavigationManager.shared
    @State private var count: Int = 0

    var body: some View {
        Button(action: {
            navigationManager.append(.pendingUploadListView(category: category, sport: sport))
        }) {
            ZStack(alignment: .topTrailing) {
                Image("record_upload")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 10, y: -8)
                }
            }
        }
        .onAppear {
            count = PendingUploadManager.shared.pendingCount(
                userID: UserManager.shared.user.userID,
                category: category,
                sport: sport
            )
        }
    }
}
