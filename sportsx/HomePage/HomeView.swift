//
//  ContentView.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/17.
//

import SwiftUI
import MapKit
import Combine
import SDWebImage
import SDWebImageSwiftUI
import UIKit


struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSportPicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .defaultBackground.softenColor(blendWithWhiteRatio: 0.2),
                            .defaultBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 自定义导航栏
                ZStack {
                    // 运动选择部分
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "list.dash")
                                .bold()
                            
                            Text(appState.sport.name)
                                .font(.headline)
                            
                            Image(systemName: appState.sport.iconName)
                                .font(.system(size: 18))
                        }
                        .foregroundStyle(.white)
                        .onTapGesture {
                            withAnimation {
                                showSportPicker.toggle()
                            }
                        }
                        .sheet(isPresented: $showSportPicker) {
                            SportPickerView()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.bottom, 20)
                
                if appState.sport == .Bike {
                    BikeSquareView(viewModel: viewModel)
                } else if appState.sport == .Running {
                    RunningSquareView()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar) // 隐藏导航栏
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: action) {
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular) // 选中状态下字体加粗
                    .foregroundColor(isSelected ? .white : .secondText)
            }
            
            if isSelected {
                Rectangle()
                    .frame(width: 20, height: 2) // 控制条状UI的宽度和高度
                    .foregroundColor(.white)
                    .matchedGeometryEffect(id: "underline", in: namespace)
            } else {
                Rectangle()
                    .frame(width: 20, height: 2)
                    .foregroundColor(.clear)
            }
        }
    }
}

struct RunningSquareView: View {
    var body: some View {
        VStack {
            Text("Running广场")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
    }
}

// 示例功能页面
struct SportSkillView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.defaultBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Text("Sport Skill页面")
                    .font(.largeTitle)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        //.border(.red)
        .enableBackGesture(true)
    }
}

struct ActivityView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.defaultBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Text("Activity页面")
                    .font(.largeTitle)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        //.border(.red)
        .enableBackGesture(true)
    }
}

struct BikeSquareView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: HomeViewModel
    @State private var adHeight: CGFloat = 200.0
    @State private var businessHeight: CGFloat = 150.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 定位区域
            
            // 广告活动推荐区域
            AdsBannerView(width: UIScreen.main.bounds.width - 20, height: adHeight, ads: viewModel.ads)
            
            // 功能组件区域
            HStack(spacing: 38) {
                ForEach(viewModel.features) { feature in
                    Button(action: {
                        appState.navigationManager.append(feature.destination)
                    }) {
                        VStack {
                            Image(systemName: feature.iconName)
                                .resizable()
                                .frame(width: 40, height: 40)
                            Text(feature.title)
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                }
                Spacer() // 确保组件从左侧开始排列
            }
            .padding(.leading, 25)
            .padding(.top, 20)
            
            // 签到区域
            HStack() {
                // 左侧签到状态
                HStack(spacing: 10) {
                    ForEach(0..<7) { day in
                        Circle()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(viewModel.isSignedIn(day: day) ? .green : .gray)
                    }
                }
                .padding(.leading, 25)
                
                Spacer()
                
                // 右侧签到按钮
                Button(action: {
                    viewModel.signInToday()
                }) {
                    Text(viewModel.isTodaySigned ? "已签到" : "签到")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        .background(viewModel.isTodaySigned ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.trailing, 20)
                .disabled(viewModel.isTodaySigned)
            }
            .padding(.top, 20)
            .onAppear() {
                viewModel.fetchSignInStatus()
            }
            
            // 商业化区域
            HStack() {
                Spacer()
                AdsBannerView(width: (UIScreen.main.bounds.width - 30) / 2, height: businessHeight, ads: viewModel.business)
                    .padding(.trailing, 10)
            }
            .padding(.top, 20)

            Spacer() // 添加Spacer将内容推到顶部
        }
    }
}

struct SportPickerView: View {
    @EnvironmentObject var appState: AppState
    //@Binding var selectedSport: SportName
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List(SportName.allCases.filter { $0.isSupported }) { sport in
                Button(action: {
                    appState.sport = sport
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: sport.iconName)
                            .foregroundColor(.blue)
                        Text(sport.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if sport == appState.sport {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("选择运动")
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    let appState = AppState.shared
    return HomeView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
    //CompetitionResultView()
}
