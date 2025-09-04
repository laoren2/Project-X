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
    @ObservedObject var navigationManager = NavigationManager.shared
    @State private var showSportPicker = false
    //@State private var isDragging: Bool = false     // 是否处于拖动中
    @State private var searchText: String = ""
    @State private var filteredPersonInfos: [PersonInfoCard] = []

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
                HStack {
                    // 搜索框
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.gray.opacity(0.1))
                            .frame(height: 30)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.leading, 12)
                            
                            TextField(text: $searchText) {
                                Text("搜索用户")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 15))
                            }
                            .foregroundStyle(.white)
                            .font(.system(size: 15))
                            
                            if !searchText.isEmpty {
                                CommonIconButton(icon: "xmark.circle.fill") {
                                    withAnimation {
                                        searchText = ""
                                    }
                                    filteredPersonInfos.removeAll()
                                }
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                                .transition(.opacity)
                            } else {
                                // 占位，保持布局一致
                                Spacer().frame(width: 12)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.trailing, 8)
                    
                    CommonTextButton(text: "搜索") {
                        filteredPersonInfos.removeAll()
                        searchAnyPersonInfoCard()
                    }
                    .foregroundStyle(.white)
                }
                .padding(.bottom, 10)
                .padding(.horizontal, 16)
                
                ZStack(alignment: .top) {
                    SquareView(viewModel: viewModel)
                    
                    if !searchText.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredPersonInfos) { person in
                                    PersonInfoCardView(person: person)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                        }
                        .background(.ultraThinMaterial)
                    }
                }
                .hideKeyboardOnScroll()
                
                //Text("to TestView")
                //    .onTapGesture {
                //        navigationManager.append(.testView)
                //    }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard)
    }
    
    func searchAnyPersonInfoCard() {
        guard var components = URLComponents(string: "/user/anyone_card") else { return }
        components.queryItems = [
            URLQueryItem(name: "phone_number", value: searchText)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        NetworkService.sendRequest(with: request, decodingType: PersonInfoDTO.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    filteredPersonInfos.append(
                        PersonInfoCard(
                            userID: unwrappedData.user_id,
                            avatarUrl: unwrappedData.avatar_image_url,
                            name: unwrappedData.nickname)
                    )
                }
            default: break
            }
        }
    }
}

/*struct TabButton: View {
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
}*/

/*struct RunningSquareView: View {
    var body: some View {
        VStack {
            Text("Running广场")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
    }
}*/

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

struct SquareView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: HomeViewModel
    @State private var adHeight: CGFloat = 200.0
    @State private var businessHeight: CGFloat = 150.0
    //@Binding var isDragging: Bool
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // 广告活动推荐区域
                AdsBannerView(width: UIScreen.main.bounds.width - 32, height: adHeight, ads: viewModel.ads)
                
                // 功能组件区域
                HStack(spacing: 38) {
                    ForEach(viewModel.features) { feature in
                        VStack {
                            Image(systemName: feature.iconName)
                                .resizable()
                                .frame(width: 40, height: 40)
                            Text(feature.title)
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.append(feature.destination)
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
                    
                    Spacer()
                    
                    // 右侧签到按钮
                    Text(viewModel.isTodaySigned ? "已签到" : "签到")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        .background(viewModel.isTodaySigned ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(viewModel.isTodaySigned)
                        .onTapGesture {
                            viewModel.signInToday()
                        }
                }
                .padding(.top, 20)
                .onAppear() {
                    viewModel.fetchSignInStatus()
                }
                
                // 商业化区域
                HStack() {
                    Spacer()
                    AdsBannerView(width: (UIScreen.main.bounds.width - 48) / 2, height: businessHeight, ads: viewModel.business)
                }
                .padding(.top, 20)
                
                Spacer() // 添加Spacer将内容推到顶部
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)
            .hideKeyboardOnScroll()
            //.onScrollDragChanged($isDragging)
        }
    }
}


#Preview {
    let appState = AppState.shared
    return HomeView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}
