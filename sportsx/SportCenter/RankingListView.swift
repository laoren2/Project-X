//
//  RankingList.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/15.
//

import SwiftUI


/*// 我的排行信息
if userManager.isLoggedIn {
    LeaderboardEntrySelfView(entry: LeaderboardEntry(user_id: userManager.user.userID, nickname: userManager.user.nickname, best_time: 55.55, avatarImageURL: NetworkService.baseDomain + userManager.user.avatarImageURL))
        .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
}

// todo
// 添加leaderboardEntries容量控制

// 排行榜
GeometryReader { geometry in
    ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {
            if viewModel.leaderboardEntries.isEmpty && !viewModel.isLoadingMore {
                Text("暂无排行榜数据")
                    .foregroundColor(.secondText)
                    .padding()
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.leaderboardEntries) { entry in
                        LeaderboardEntryView(entry: entry)
                            .onAppear {
                                if entry == viewModel.leaderboardEntries.last {
                                    viewModel.fetchLeaderboard(gender: viewModel.gender)
                                }
                            }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
    }
    .frame(height: 600)
    .frame(alignment: .top)
    .offset(y: chevronDirection ? 0 : -210) // 控制视图滑出/滑入
}*/
