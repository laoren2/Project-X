//
//  CareerView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import SwiftUI

struct CareerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserViewModel
    @State private var selectedSeason = "X1赛季"
    @State private var showSeasonPicker = false
    
    let seasons = ["X1赛季", "X2赛季", "X3赛季"]
    let abilities = ["技巧", "装备", "心肺", "有氧", "爆发"]
    let abilityValues: [Float] = [80.0, 65.7, 70.4, 90.9, 75.3] // 示例数据
    
    var body: some View {
        VStack(spacing: 20) {
            // 赛季选择器 - 使用Menu组件
            HStack {
                Menu {
                    ForEach(seasons, id: \.self) { season in
                        Button(season) {
                            selectedSeason = season
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSeason)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    //.background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // 积分排名和能力图区域
            HStack(alignment: .top, spacing: 15) {
                // 积分排名区域
                VStack(spacing: 15) {
                    statsCard(title: "赛季积分", value: "\(viewModel.totalScore)", iconName: "star.fill", color: .green)
                    
                    statsCard(title: "赛季排名", value: "#\(viewModel.totalRank)", iconName: "trophy.fill", color: .red)
                    
                    // 荣誉展示
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
                
                // 五边形能力图
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
            .padding(.horizontal)
            
            // 参与数据区域
            VStack(spacing: 15) {
                Text("赛季数据")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 15) {
                    dataCard(title: "参与时间", value: formatTime(minutes: viewModel.totalTime), iconName: "clock.fill", color: .green)
                    
                    dataCard(title: "参与路程", value: formatDistance(meters: viewModel.totalMeters), iconName: "figure.run", color: .blue)
                    
                    dataCard(title: "获得奖金", value: "¥\(viewModel.totalBonus)", iconName: "dollarsign.circle.fill", color: .yellow)
                }
            }
            .padding(.horizontal)
            
            // 赛事积分记录
            VStack(alignment: .leading, spacing: 10) {
                Text("赛事积分记录")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.competitionScoreRecords) { record in
                        CompetitionScoreCard(trackRecord: record)
                    }
                }
            }
            .padding(.horizontal)
        }
        //.border(.green)
    }
    
    // 统计卡片
    private func statsCard(title: String, value: String, iconName: String, color: Color) -> some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondText)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(.gray.opacity(0.5))
        .cornerRadius(12)
    }
    
    // 数据卡片
    private func dataCard(title: String, value: String, iconName: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.gray.opacity(0.5))
        .cornerRadius(10)
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
    
    // 格式化时间
    private func formatTime(minutes: Int) -> String {
        let hours = minutes / 60
        return "\(hours)h"
    }
    
    // 格式化距离
    private func formatDistance(meters: Int) -> String {
        let kilometers = Double(meters) / 1000.0
        return String(format: "%.1fkm", kilometers)
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
    let trackRecord: TrackScoreRecord
    
    var body: some View {
        VStack(spacing: 0) {
            // 赛事名称头部
            HStack {
                Text(trackRecord.eventName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(trackRecord.city)
                    .font(.subheadline)
                    .foregroundColor(.secondText)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.8))
            
            // 赛道和积分信息
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(trackRecord.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: "rosette")
                            .foregroundColor(.pink)
                        
                        Text("积分级别 \(trackRecord.scoreLevel)")
                            .font(.subheadline)
                            .foregroundColor(.secondText)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("\(trackRecord.score)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("积分")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.secondText)
                .cornerRadius(10)
            }
            .padding()
            .background(.gray.opacity(0.5))
        }
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}


#Preview {
    let appState = AppState.shared
    let vm = UserViewModel(id: "123321", needBack: false)
    CareerView(viewModel: vm)
        .environmentObject(appState)
}
