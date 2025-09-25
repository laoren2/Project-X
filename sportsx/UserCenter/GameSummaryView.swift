//
//  GameSummaryView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import SwiftUI

struct GameSummaryView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: UserViewModel
    
    var body: some View {
        if (!viewModel.isNeedBack) && (!userManager.isLoggedIn) {
            Text("登录后查看")
                .foregroundStyle(Color.secondText)
                .padding(.top, 100)
        } else {
            LazyVStack(spacing: 15) {
                ForEach(viewModel.gameSummaryCards) { card in
                    GameSummaryCardView(viewModel: viewModel, gameSummaryCard: card)
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }
}

struct GameSummaryCardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserViewModel
    let gameSummaryCard: GameSummaryCard
    
    var body: some View {
        VStack {
            HStack {
                Text(gameSummaryCard.eventname)
                Spacer()
                Text(gameSummaryCard.trackName)
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.blue)
                Text(gameSummaryCard.cityName)
            }
            Divider()
            HStack {
                Text("PB")
                    .font(.system(size: 15))
                    .bold()
                    .padding(.horizontal, 5)
                    .background(.green.opacity(0.6))
                    .cornerRadius(5)
                Text(TimeDisplay.formattedTime(gameSummaryCard.best_time))
                Spacer()
                Text("No.\(gameSummaryCard.rank)")
                    .bold()
            }
            Divider()
            HStack {
                Image(systemName: CCAssetType.voucher.iconName)
                    .foregroundStyle(.yellow)
                Text("\(gameSummaryCard.voucher)")
                    .bold()
                Spacer()
                Image(systemName: "staroflife.fill")
                    .foregroundStyle(.red)
                Text("\(gameSummaryCard.score)")
                    .bold()
            }
            Divider()
            HStack {
                Spacer()
                Text("详情")
                    .padding(.vertical, 5)
                    .padding(.horizontal)
                    .background(Color.orange)
                    .cornerRadius(10)
                    .exclusiveTouchTapGesture {
                        if viewModel.sport == .Bike {
                            appState.navigationManager.append(.bikeRecordDetailView(recordID: gameSummaryCard.record_id, userID: viewModel.userID))
                        } else if viewModel.sport == .Running {
                            appState.navigationManager.append(.runningRecordDetailView(recordID: gameSummaryCard.record_id, userID: viewModel.userID))
                        }
                    }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .foregroundStyle(Color.secondText)
        .background(.gray.opacity(0.5))
        .cornerRadius(10)
    }
}

struct GameSummaryCard: Identifiable {
    var id: String { record_id }
    let record_id: String
    let eventname: String
    let trackName: String
    let cityName: String
    let best_time: TimeInterval
    let rank: Int
    let voucher: Int
    let score: Int
    //let magicCards: [MagicCard]
    
    init(from card: GameSummaryCardDTO) {
        self.record_id = card.record_id
        self.eventname = card.event_name
        self.trackName = card.track_name
        self.cityName = card.city_name
        self.best_time = card.best_time
        self.rank = card.rank
        self.voucher = card.voucher
        self.score = card.score
    }
}

struct GameSummaryCardDTO: Codable {
    let record_id: String
    let event_name: String
    let track_name: String
    let city_name: String
    let best_time: Double
    let rank: Int
    let voucher: Int
    let score: Int
}

struct GameSummaryResponse: Codable {
    let records: [GameSummaryCardDTO]
}

#Preview {
    let appState = AppState.shared
    let vm = UserViewModel(id: "qweasd", needBack: false)
    GameSummaryView(viewModel: vm)
        .environmentObject(appState)
}
