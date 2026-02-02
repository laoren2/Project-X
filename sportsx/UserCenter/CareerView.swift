//
//  CareerView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import SwiftUI

struct CareerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: UserViewModel
    //let abilities = ["技巧", "装备", "心肺", "有氧", "爆发"]
    //let abilityValues: [Float] = [80.0, 65.7, 70.4, 90.9, 75.3] // 示例数据
    
    var body: some View {
        VStack(spacing: 20) {
            // 暂时为适配 iOS16+ 的写法
            // todo: 替换为更稳定的自定义menu
            
            HStack {
                if let seasonName = viewModel.selectedSeason?.seasonName {
                    Menu {
                        ForEach(viewModel.seasons) { season in
                            Button(action: {
                                viewModel.selectedSeason = season
                            }) {
                                Text(LocalizedStringKey(season.seasonName))
                            }
                        }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(seasonName))
                                .font(.subheadline)
                                .foregroundStyle(Color.white)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.4))
                        .cornerRadius(8)
                    }
                } else {
                    Text("error.unknown")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.4))
                        .cornerRadius(8)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // 积分排名和能力图区域
            /*HStack(alignment: .top, spacing: 15) {
             // 积分排名区域
             VStack(spacing: 15) {
             // todo: 荣誉展示
             VStack(alignment: .leading, spacing: 10) {
             Text("赛季荣誉")
             .font(.headline)
             .foregroundColor(.secondText)
             
             HStack {
             ForEach(viewModel.cups) { cup in
             Image(systemName: cup.image)
             .font(.title)
             .foregroundColor(.yellow)
             }
             Spacer()
             if viewModel.cups.isEmpty {
             Text("暂无荣誉")
             .font(.subheadline)
             .foregroundColor(.secondText)
             }
             }
             }
             .padding()
             .background(.gray.opacity(0.5))
             .cornerRadius(12)
             }
             .frame(maxWidth: .infinity)
             
             // todo: 五边形能力图
             VStack(spacing: 15) {
             ZStack {
             // 五边形背景
             PolygonShape(sides: 5)
             .stroke(Color.gray.opacity(0.3), lineWidth: 1)
             .frame(width: 150, height: 150)
             
             // 能力值五边形
             AbilityPolygon(values: abilityValues)
             .fill(Color.blue.opacity(0.3))
             .frame(width: 150, height: 150)
             
             // 能力点
             AbilityPolygon(values: abilityValues)
             .stroke(Color.blue, lineWidth: 2)
             .frame(width: 150, height: 150)
             }
             
             // 能力值条
             VStack(spacing: 8) {
             ForEach(0..<abilities.count, id: \.self) { index in
             abilityBar(ability: abilities[index], value: abilityValues[index])
             }
             }
             }
             .frame(maxWidth: .infinity)
             }
             .padding(.horizontal)*/
            
            // 参与数据区域
            VStack(spacing: 15) {
                HStack {
                    Text("competition.season.data")
                    Spacer()
                }
                .font(.headline)
                .foregroundStyle(.white)
                
                VStack {
                    HStack {
                        Text("competition.season.score")
                        Spacer()
                        Text("\(viewModel.totalScore)")
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    Divider()
                    HStack {
                        Text("competition.season.ranking")
                        Spacer()
                        if let rank = viewModel.totalRank {
                            Text("\(rank)")
                        } else {
                            Text("error.no_data")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.white)
                    Divider()
                    HStack(alignment: .bottom, spacing: 15) {
                        VStack(spacing: 5) {
                            Image("total_time")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25)
                            (Text(String(format: "%.2f", viewModel.totalTime / 3600)) + Text("time.hour"))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.white)
                            Text("competition.season.total_time")
                                .font(.caption)
                                .foregroundStyle(Color.secondText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        
                        VStack(spacing: 5) {
                            Image("total_distance")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25)
                            (Text(String(format: "%.2f", viewModel.totalDistance)) + Text("distance.km"))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.white)
                            Text("competition.season.total_distance")
                                .font(.caption)
                                .foregroundStyle(Color.secondText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        
                        VStack(spacing: 5) {
                            Image("voucher")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25)
                            Text("\(viewModel.totalBonus)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.white)
                            Text("competition.season.total_rewards")
                                .font(.caption)
                                .foregroundStyle(Color.secondText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .padding()
                .background(.white.opacity(0.3))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            // 赛事积分记录
            VStack(spacing: 10) {
                HStack {
                    Text("competition.season.event_records")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                if viewModel.competitionScoreRecords.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                        Text("error.no_data")
                            .font(.headline)
                    }
                    .foregroundStyle(Color.white.opacity(0.3))
                    Spacer()
                } else {
                    LazyVStack(spacing: 15) {
                        ForEach(viewModel.competitionScoreRecords) { record in
                            CompetitionScoreCard(sport: viewModel.sport, trackRecord: record)
                        }
                    }
                }
            }
            .padding(.horizontal)
            Spacer()
        }
        .frame(minHeight: 700)
    }
    
    // 能力条
    private func abilityBar(ability: String, value: Float) -> some View {
        HStack {
            Text(ability)
                .font(.caption)
                .frame(width: 30, alignment: .leading)
                .foregroundColor(.white)
                //.border(.green)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 6)
                        .opacity(0.2)
                        .foregroundColor(.gray)
                    
                    Rectangle()
                        .frame(width: geometry.size.width * CGFloat(value) / 100, height: 6)
                        .foregroundColor(.blue)
                }
            }
            .frame(height: 6)
            
            Text(String(format: "%.1f", value))
                .font(.caption)
                .frame(width: 30)
                .foregroundColor(.white)
                //.border(.red)
        }
    }
}


struct LocalCareerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: LocalUserViewModel
    
    
    var body: some View {
        VStack(spacing: 20) {
            if !userManager.isLoggedIn {
                Spacer()
                Text("toast.no_login.2")
                    .foregroundStyle(Color.secondText)
                    .padding(.top, 100)
            } else {
                HStack {
                    // todo: 替换为更稳定的自定义menu
                    if let seasonName = viewModel.selectedSeason?.seasonName {
                        Menu {
                            ForEach(viewModel.seasons) { season in
                                Button(action: {
                                    viewModel.selectedSeason = season
                                }) {
                                    Text(LocalizedStringKey(season.seasonName))
                                }
                            }
                        } label: {
                            HStack {
                                Text(LocalizedStringKey(seasonName))
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.4))
                            .cornerRadius(8)
                        }
                    } else {
                        Text("error.unknown")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color.white.opacity(0.4))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 参与数据区域
                VStack(spacing: 15) {
                    HStack {
                        Text("competition.season.data")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        HStack {
                            Text("competition.season.score.leaderboard")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.secondText)
                        .exclusiveTouchTapGesture {
                            if let season = viewModel.selectedSeason {
                                if viewModel.sport == .Bike {
                                    appState.navigationManager.append(.bikeScoreRankingView(seasonName: season.seasonName, seasonID: season.seasonID, gender: UserManager.shared.user.gender ?? .male))
                                } else if viewModel.sport == .Running {
                                    appState.navigationManager.append(.runningScoreRankingView(seasonName: season.seasonName, seasonID: season.seasonID, gender: UserManager.shared.user.gender ?? .male))
                                }
                            }
                        }
                    }
                    
                    VStack {
                        HStack {
                            Text("competition.season.score")
                            Spacer()
                            Text("\(viewModel.totalScore)")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                        Divider()
                        HStack {
                            Text("competition.season.ranking")
                            Spacer()
                            if let rank = viewModel.totalRank {
                                Text("\(rank)")
                            } else {
                                Text("error.no_data")
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.white)
                        Divider()
                        HStack(alignment: .bottom, spacing: 15) {
                            VStack(spacing: 5) {
                                Image("total_time")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25)
                                (Text(String(format: "%.2f", viewModel.totalTime / 3600)) + Text("time.hour"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.white)
                                Text("competition.season.total_time")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            
                            VStack(spacing: 5) {
                                Image("total_distance")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25)
                                (Text(String(format: "%.2f", viewModel.totalDistance)) + Text("distance.km"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.white)
                                Text("competition.season.total_distance")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            
                            VStack(spacing: 5) {
                                Image("voucher")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 25)
                                Text("\(viewModel.totalBonus)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.white)
                                Text("competition.season.total_rewards")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding()
                    .background(.white.opacity(0.3))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // 赛事积分记录
                VStack(spacing: 10) {
                    HStack {
                        Text("competition.season.event_records")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    if viewModel.competitionScoreRecords.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                            Text("error.no_data")
                                .font(.headline)
                        }
                        .foregroundStyle(Color.white.opacity(0.3))
                        Spacer()
                    } else {
                        LazyVStack(spacing: 15) {
                            ForEach(viewModel.competitionScoreRecords) { record in
                                CompetitionScoreCard(sport: viewModel.sport, trackRecord: record)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .frame(minHeight: 600)
    }
    
    // 能力条
    private func abilityBar(ability: String, value: Float) -> some View {
        HStack {
            Text(ability)
                .font(.caption)
                .frame(width: 30, alignment: .leading)
                .foregroundColor(.white)
                //.border(.green)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 6)
                        .opacity(0.2)
                        .foregroundColor(.gray)
                    
                    Rectangle()
                        .frame(width: geometry.size.width * CGFloat(value) / 100, height: 6)
                        .foregroundColor(.blue)
                }
            }
            .frame(height: 6)
            
            Text(String(format: "%.1f", value))
                .font(.caption)
                .frame(width: 30)
                .foregroundColor(.white)
                //.border(.red)
        }
    }
}


// 五边形形状
struct PolygonShape: Shape {
    var sides: Int
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        let angle = Double.pi * 2 / Double(sides)
        
        for i in 0..<sides {
            let currentAngle = angle * Double(i) - (Double.pi / 2)
            let x = center.x + CGFloat(cos(currentAngle)) * radius
            let y = center.y + CGFloat(sin(currentAngle)) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// 能力值五边形
struct AbilityPolygon: Shape {
    var values: [Float]
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        let sides = values.count
        
        var path = Path()
        let angle = Double.pi * 2 / Double(sides)
        
        for i in 0..<sides {
            let value = Double(values[i]) / 100.0
            let currentAngle = angle * Double(i) - (Double.pi / 2)
            let x = center.x + CGFloat(cos(currentAngle)) * radius * CGFloat(value)
            let y = center.y + CGFloat(sin(currentAngle)) * radius * CGFloat(value)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

struct CompetitionScoreCard: View {
    @EnvironmentObject var appState: AppState
    let userManager = UserManager.shared
    @State var sport: SportName
    let trackRecord: CareerRecord
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(trackRecord.eventName)
                    .foregroundColor(.white)
                Spacer()
                Text(LocalizedStringKey(trackRecord.region))
                    .foregroundColor(.secondText)
            }
            .fontWeight(.bold)
            .foregroundStyle(Color.white)
            
            Divider()
            
            // 赛道和积分信息
            HStack(alignment: .center) {
                Text(trackRecord.trackName)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(alignment: .center) {
                    Text("+ \(trackRecord.score)/\(trackRecord.trackScore)")
                    Text("competition.track.leaderboard.score")
                }
            }
            .foregroundColor(.secondText)
            
            Divider()
            
            HStack(alignment: .center) {
                Text("time.date")
                Spacer()
                Text(LocalizedStringKey(DateDisplay.formattedDate(trackRecord.recordDate)))
            }
            .foregroundColor(.secondText)
            
            Divider()
            
            HStack {
                HStack(spacing: 4) {
                    Text("competition.record.detail")
                    Image(systemName: "chevron.right")
                }
                .exclusiveTouchTapGesture {
                    if sport == .Bike {
                        appState.navigationManager.append(.bikeRecordDetailView(recordID: trackRecord.recordID))
                    } else if sport == .Running {
                        appState.navigationManager.append(.runningRecordDetailView(recordID: trackRecord.recordID))
                    }
                }
                Spacer()
                
                HStack(spacing: 4) {
                    Text("competition.track.leaderboard.ranking.2")
                    Image(systemName: "chevron.right")
                }
                .exclusiveTouchTapGesture {
                    if sport == .Bike {
                        appState.navigationManager.append(.bikeRankingListView(trackID: trackRecord.trackID, gender: userManager.user.gender ?? .male, isHistory: true))
                    } else if sport == .Running {
                        appState.navigationManager.append(.runningRankingListView(trackID: trackRecord.trackID, gender: userManager.user.gender ?? .male, isHistory: true))
                    }
                }
            }
            .foregroundStyle(Color.secondText)
        }
        .font(.subheadline)
        .padding()
        .background(.white.opacity(0.3))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    let appState = AppState.shared
    let vm = UserViewModel(id: "123321")
    CareerView(viewModel: vm)
        .environmentObject(appState)
}
