//
//  CompetitionResultView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/15.
//

import SwiftUI
import MapKit


struct BikeRecordDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: BikeRecordDetailViewModel
    
    init(recordID: String, userID: String) {
        _viewModel = StateObject(wrappedValue: BikeRecordDetailViewModel(recordID: recordID, userID: userID))
    }
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    adjustNavigationPath()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("bike比赛结算")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            if let detailInfo = viewModel.recordDetailInfo {
                ScrollView {
                    VStack(spacing: 20) {
                        // Map-style placeholder showing path segments colored by speed
                        if !detailInfo.path.isEmpty {
                            GradientPathMapView(path: detailInfo.path)
                                .frame(height: 220)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        
                        // Original time, final time, and status
                        VStack(spacing: 8) {
                            HStack {
                                Text("原始时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.originalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("有效时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.finalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("状态:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                if detailInfo.isFinishComputed == false {
                                    Text("计算中...")
                                        .foregroundColor(.orange)
                                        .bold()
                                } else {
                                    Text("已完成")
                                        .foregroundColor(.green)
                                        .bold()
                                }
                            }
                        }
                        .padding()
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // List of card bonuses
                        if !detailInfo.cardBonus.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("卡牌收益")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                    .padding(.horizontal)
                                ForEach(detailInfo.cardBonus) { bonus in
                                    HStack(spacing: 16) {
                                        MagicCardView(card: bonus.card)
                                            .frame(width: 60)
                                        VStack(alignment: .leading) {
                                            Spacer()
                                            Text(bonus.card.name)
                                                .font(.headline)
                                                .bold()
                                                .foregroundStyle(Color.secondText)
                                            Spacer()
                                            Text("奖励时间: \(bonus.bonusTime)")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // team mode 下的队友状态和成绩
                        if !detailInfo.teamMemberScores.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("队伍状态")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                    .padding(.horizontal)
                                ForEach(detailInfo.teamMemberScores) { score in
                                    HStack(spacing: 16) {
                                        HStack(spacing: 10) {
                                            CachedAsyncImage(
                                                urlString: score.userInfo.avatarUrl,
                                                placeholder: Image(systemName: "person"),
                                                errorImage: Image(systemName: "photo.badge.exclamationmark")
                                            )
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.userView(id: score.userInfo.userID, needBack: true))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(score.userInfo.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(Color.secondText)
                                            }
                                        }
                                        Spacer()
                                        HStack {
                                            Text(score.status.rawValue)
                                                .font(.caption)
                                                .padding(.vertical, 5)
                                                .padding(.horizontal, 8)
                                                .foregroundStyle(Color.secondText)
                                                .background(Color.orange.opacity(0.5))
                                                .cornerRadius(10)
                                            Text("成绩: \(TimeDisplay.formattedTime(score.finalTime, showFraction: true))")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                VStack {
                    Spacer()
                    Text("找不到数据")
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture() {
            adjustNavigationPath()
        }
        .onFirstAppear {
            viewModel.queryRecordDetail()
        }
    }
    
    private func adjustNavigationPath() {
        var cardSelectViewIndex = 1
        var realtimeViewIndex = 1
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
            cardSelectViewIndex = appState.navigationManager.path.count - index
        }
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionRealtimeView" }) {
            realtimeViewIndex = appState.navigationManager.path.count - index
        }
        let lastToRemove = max(1, cardSelectViewIndex, realtimeViewIndex)
        appState.navigationManager.removeLast(lastToRemove)
    }
}

struct RunningRecordDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: RunningRecordDetailViewModel
    
    init(recordID: String, userID: String) {
        _viewModel = StateObject(wrappedValue: RunningRecordDetailViewModel(recordID: recordID, userID: userID))
    }
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    adjustNavigationPath()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("running比赛结算")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            if let detailInfo = viewModel.recordDetailInfo {
                ScrollView {
                    VStack(spacing: 20) {
                        if !detailInfo.path.isEmpty {
                            GradientPathMapView(path: detailInfo.path)
                                .frame(height: 220)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("原始时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.originalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("有效时间:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                Text("\(detailInfo.finalTime)")
                                    .font(.system(.body, design: .rounded))
                                    .bold()
                                    .foregroundStyle(Color.white)
                            }
                            HStack {
                                Text("状态:")
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                Spacer()
                                if detailInfo.isFinishComputed == false {
                                    Text("计算中...")
                                        .foregroundColor(.orange)
                                        .bold()
                                } else {
                                    Text("已完成")
                                        .foregroundColor(.green)
                                        .bold()
                                }
                            }
                        }
                        .padding()
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        if !detailInfo.cardBonus.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("卡牌收益")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                    .padding(.horizontal)
                                ForEach(detailInfo.cardBonus) { bonus in
                                    HStack(spacing: 16) {
                                        MagicCardView(card: bonus.card)
                                            .frame(width: 60)
                                        VStack(alignment: .leading) {
                                            Spacer()
                                            Text(bonus.card.name)
                                                .font(.headline)
                                                .bold()
                                                .foregroundStyle(Color.secondText)
                                            Spacer()
                                            Text("奖励时间: \(bonus.bonusTime)")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        if !detailInfo.teamMemberScores.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("队伍状态")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(Color.secondText)
                                    .padding(.horizontal)
                                ForEach(detailInfo.teamMemberScores) { score in
                                    HStack(spacing: 16) {
                                        HStack(spacing: 10) {
                                            CachedAsyncImage(
                                                urlString: score.userInfo.avatarUrl,
                                                placeholder: Image(systemName: "person"),
                                                errorImage: Image(systemName: "photo.badge.exclamationmark")
                                            )
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .exclusiveTouchTapGesture {
                                                appState.navigationManager.append(.userView(id: score.userInfo.userID, needBack: true))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(score.userInfo.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(Color.secondText)
                                            }
                                        }
                                        Spacer()
                                        HStack {
                                            Text(score.status.rawValue)
                                                .font(.caption)
                                                .padding(.vertical, 5)
                                                .padding(.horizontal, 8)
                                                .foregroundStyle(Color.secondText)
                                                .background(Color.orange.opacity(0.5))
                                                .cornerRadius(10)
                                            Text("成绩: \(TimeDisplay.formattedTime(score.finalTime, showFraction: true))")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                VStack {
                    Spacer()
                    Text("找不到数据")
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture() {
            adjustNavigationPath()
        }
        .onFirstAppear {
            viewModel.queryRecordDetail()
        }
    }
    
    private func adjustNavigationPath() {
        var cardSelectViewIndex = 1
        var realtimeViewIndex = 1
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
            cardSelectViewIndex = appState.navigationManager.path.count - index
        }
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionRealtimeView" }) {
            realtimeViewIndex = appState.navigationManager.path.count - index
        }
        let lastToRemove = max(1, cardSelectViewIndex, realtimeViewIndex)
        appState.navigationManager.removeLast(lastToRemove)
    }
}


#Preview {
    let appState = AppState.shared
    return BikeRecordDetailView(recordID: "test", userID: "")
        .environmentObject(appState)
}
