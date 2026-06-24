//
//  InProgressRecordCardView.swift
//  sportsx
//
//  进行中比赛记录的卡片及其数据模型。
//  展示于个人主页 Career 模块的「进行中」筛选下（已完成记录见 CompetitionScoreCard）。
//

import SwiftUI

struct InProgressRecordCardView: View {
    @EnvironmentObject var appState: AppState
    @State var sport: SportName
    let record: InProgressRecord

    var regionName: LocalizedStringKey? {
        guard let region = RegionStore.index[record.regionID] else { return nil }
        return LocalizedStringKey(region.regionName)
    }

    var body: some View {
        VStack {
            HStack(spacing: 5) {
                Text(record.eventname)
                Spacer()
                Text(record.trackName)
                Spacer()
                Image("location")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(regionName ?? "error.unknown")
            }
            .font(.headline)
            .foregroundStyle(Color.white)
            Divider()
            HStack {
                Text("PB")
                    .font(.system(size: 15))
                    .bold()
                    .padding(.horizontal, 5)
                    .background(.green.opacity(0.6))
                    .cornerRadius(5)
                Text(TimeDisplay.formattedTime(record.best_time))
                Spacer()
                Text("competition.track.leaderboard.ranking") + Text(": \(record.rank)")
                Spacer()
                HStack(spacing: 4) {
                    Image("season_points")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text("\(record.score)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            Divider()
            HStack(spacing: 5) {
                Image(CCAssetType.voucher.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("\(record.voucher)")
                Spacer()
                HStack(spacing: 4) {
                    Text("action.detail")
                    Image(systemName: "chevron.right")
                }
                .exclusiveTouchTapGesture {
                    if sport == .Bike {
                        appState.navigationManager.append(.bikeRaceRecordDetailView(recordID: record.record_id))
                    } else if sport == .Running {
                        appState.navigationManager.append(.runningRaceRecordDetailView(recordID: record.record_id))
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.3))
        .cornerRadius(10)
    }
}

struct InProgressRecord: Identifiable {
    var id: String { record_id }
    let record_id: String
    let eventname: String
    let trackName: String
    let regionID: String
    let best_time: TimeInterval
    let rank: Int
    let voucher: Int
    let score: Int

    init(from card: InProgressRecordDTO) {
        self.record_id = card.record_id
        self.eventname = card.event_name
        self.trackName = card.track_name
        self.regionID = card.region_id
        self.best_time = card.best_time
        self.rank = card.rank
        self.voucher = card.voucher
        self.score = card.score
    }
}

struct InProgressRecordDTO: Codable {
    let record_id: String
    let event_name: String
    let track_name: String
    let region_id: String
    let best_time: Double
    let rank: Int
    let voucher: Int
    let score: Int
}

struct InProgressRecordsResponse: Codable {
    let records: [InProgressRecordDTO]
}
