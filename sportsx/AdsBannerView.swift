//
//  AdsBannerView.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/3.
//

import SwiftUI
import Combine

struct AdsCard: View {
    let width: CGFloat
    let height: CGFloat
    let image: String
    var body: some View {
        AsyncImage(url: URL(string: image)) { phase in
            switch phase {
            case .empty:
                Image("Ads") // 使用本地图片作为占位符
                    .resizable()
                    .scaledToFill()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image("Ads2") // 使用本地图片作为错误占位符
                    .resizable()
                    .scaledToFill()
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

struct AdsBannerView: View {
    @EnvironmentObject var appState: AppState
    
    var width: CGFloat
    var height: CGFloat
    
    @State var ads: [Ad]
    @State var currentIndex = 1
    @State var tempOffset: CGFloat = 0
    @State private var cancellable: AnyCancellable? = nil
    
    @GestureState var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                // 添加一个重复的最后一页用于无限循环
                AdsCard(width: width, height: height, image: ads.last?.imageURL ?? "")
                    .frame(width: width, height: height)
                
                ForEach(ads.indices, id: \.self) { index in
                    AdsCard(width: width, height: height, image: ads[index].imageURL)
                        .frame(width: width, height: height)
                }
                // 添加一个重复的第一页用于无限循环
                AdsCard(width: width, height: height, image: ads.first?.imageURL ?? "")
                    .frame(width: width, height: height)
            }
            .frame(width: width, height: height, alignment: .leading)
            .offset(x: -CGFloat(self.currentIndex) * width)
            .offset(x: self.tempOffset)
            .onChange(of: currentIndex) {
                if currentIndex == ads.count + 1 {
                    currentIndex = 1
                } else if currentIndex == 0 {
                    currentIndex = ads.count
                }
            }
            // 拖动事件
            // todo: 考虑拖动速度优化交互
            .gesture(
                DragGesture()
                    .updating(self.$dragOffset, body: { value, state, transaction in
                        if cancellable != nil {
                            stopAutoScroll()
                        }
                        state = value.translation.width
                        tempOffset = state
                    })
                    .onEnded({ value in
                        let threshold = width * 0.25
                        var newIndex = self.currentIndex
                        var newTempOffset = width
                        if value.translation.width < -threshold {
                            newIndex += 1
                            newTempOffset = -newTempOffset
                        } else if value.translation.width > threshold {
                            newIndex -= 1
                        } else {
                            newTempOffset = 0
                        }
                        withAnimation {
                            tempOffset = newTempOffset
                        }
                        self.currentIndex = newIndex
                        tempOffset = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            startAutoScroll()
                        }
                    })
            )
            .onAppear() {
                startAutoScroll()
            }
            .onDisappear {
                stopAutoScroll()
            }
            
            // 分页指示器
            HStack(spacing: 8) {
                ForEach(ads.indices, id: \.self) { index in
                    Circle()
                        .fill(index + 1 == currentIndex ? Color.gray : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 10)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // 开始自动滚动
    func startAutoScroll() {
        //print("startAutoScroll")
        guard ads.count > 0 else { return }

        // 如果 Timer 已经存在，则不再创建新的 Timer
        if cancellable != nil {
            return
        }
        // 创建一个 Timer Publisher，每隔3秒发送一次事件
        cancellable = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if currentIndex == ads.count + 1 {
                    currentIndex = 1
                }
                // 比赛进行中主线程繁忙，切换动画可能不流畅
                if appState.competitionManager.isRecording {
                    currentIndex += 1
                } else {
                    withAnimation(.smooth) {
                        currentIndex += 1 //= (currentIndex + 1) % ads.count
                    }
                }
            }
    }
    
    // 停止自动滚动
    func stopAutoScroll() {
        //print("stopAutoScroll")
        cancellable?.cancel()
        cancellable = nil
    }
}
