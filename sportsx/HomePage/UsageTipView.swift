//
//  UsageTipView.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/27.
//

import SwiftUI

struct UsageTipView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    
    let sections: [UsageTipSection] = [
        UsageTipSection(
            rank: 1,
            title: "home.skill.title.1",
            items: [
                UsageTipItem(rank: 1, subtitle: "home.skill.title.1.subtitle.1", content: "home.skill.title.1.subtitle.1.content"),
                UsageTipItem(rank: 2, subtitle: "home.skill.title.1.subtitle.2", content: "home.skill.title.1.subtitle.2.content"),
                UsageTipItem(rank: 3, subtitle: "competition.track.prize_pool", content: "home.skill.title.1.subtitle.3.content")
            ]
        ),
        UsageTipSection(
            rank: 2,
            title: "home.skill.title.2",
            items: [
                UsageTipItem(rank: 1, subtitle: "home.skill.title.2.subtitle.1", content: "home.skill.title.2.subtitle.1.content"),
                UsageTipItem(rank: 2, subtitle: "home.skill.title.2.subtitle.2", content: "home.skill.title.2.subtitle.2.content"),
                UsageTipItem(rank: 3, subtitle: "home.skill.title.2.subtitle.3", content: "home.skill.title.2.subtitle.3.content"),
                UsageTipItem(rank: 4, subtitle: "home.skill.title.2.subtitle.4", content: "home.skill.title.2.subtitle.4.content")
            ]
        ),
        UsageTipSection(
            rank: 3,
            title: "home.skill.title.3",
            items: [
                UsageTipItem(rank: 1, subtitle: "home.skill.title.3.subtitle.1", content: "home.skill.title.3.subtitle.1.content"),
                UsageTipItem(rank: 2, subtitle: "home.skill.title.3.subtitle.2", content: "home.skill.title.3.subtitle.2.content"),
                UsageTipItem(rank: 3, subtitle: "home.skill.title.3.subtitle.3", content: "home.skill.title.3.subtitle.3.content")
            ]
        ),
        UsageTipSection(
            rank: 4,
            title: "home.skill.title.4",
            items: [
                UsageTipItem(rank: 1, subtitle: "competition.record.result", content: "home.skill.title.4.subtitle.1.content"),
                UsageTipItem(rank: 2, subtitle: "home.skill.title.4.subtitle.2", content: "home.skill.title.4.subtitle.2.content"),
                UsageTipItem(rank: 3, subtitle: "home.skill.title.4.subtitle.3", content: "home.skill.title.4.subtitle.3.content")
            ]
        ),
        UsageTipSection(
            rank: 5,
            title: "home.skill.title.5",
            items: [
                UsageTipItem(rank: 1, subtitle: "home.skill.title.5.subtitle.1", content: "home.skill.title.5.subtitle.1.content"),
                UsageTipItem(rank: 2, subtitle: "home.skill.title.5.subtitle.2", content: "home.skill.title.5.subtitle.2.content"),
                UsageTipItem(rank: 3, subtitle: "home.skill.title.5.subtitle.3", content: "home.skill.title.5.subtitle.3.content")
            ]
        )
    ]
    
    @State private var expandedSections: [Bool]
    
    init() {
        _expandedSections = State(initialValue: Array(repeating: false, count: sections.count))
    }
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondText)
                Spacer()
                Text("home.skill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.secondText)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            Text("home.skill.title")
                .font(.title2)
                .foregroundStyle(Color.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                VStack {
                    ForEach(0..<sections.count, id: \.self) { index in
                        HStack {
                            (Text("\(sections[index].rank). ") + Text(LocalizedStringKey(sections[index].title)))
                                .font(.title2)
                                .foregroundStyle(Color.white)
                            Spacer()
                        }
                        .padding(.vertical)
                        .contentShape(Rectangle())
                        .exclusiveTouchTapGesture {
                            expandedSections[index].toggle()
                        }
                        if expandedSections[index] {
                            VStack(spacing: 20) {
                                ForEach(sections[index].items) { item in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            (Text("\(sections[index].rank).\(item.rank) ") + Text(LocalizedStringKey(item.subtitle)))
                                                .font(.title3)
                                                .foregroundStyle(Color.white)
                                            Spacer()
                                        }
                                        JustifiedText(localizedKey: item.content, font: .systemFont(ofSize: 20), textColor: UIColor(Color.secondText))
                                    }
                                }
                            }
                            .padding(.vertical)
                            .contentShape(Rectangle())
                            .exclusiveTouchTapGesture {
                                expandedSections[index].toggle()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}

struct UsageTipSection: Identifiable {
    let id = UUID()
    let rank: Int
    let title: String
    let items: [UsageTipItem]
}

struct UsageTipItem: Identifiable {
    let id = UUID()
    let rank: Int
    let subtitle: String
    let content: String
}

#Preview{
    UsageTipView()
}
