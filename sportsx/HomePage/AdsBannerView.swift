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
        CachedAsyncImage(
            urlString: image,
            placeholder: Image("Ads"),
            errorImage: Image(systemName: "photo.badge.exclamationmark")
        )
        .scaledToFill()
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
    var totalOffset: CGFloat {
        return -CGFloat(self.currentIndex) * width + self.tempOffset
    }
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
            .offset(x: totalOffset)
            .onChange(of: currentIndex) {
                if currentIndex == ads.count + 1 {
                    currentIndex = 1
                } else if currentIndex == 0 {
                    currentIndex = ads.count
                }
            }
            // 拖动事件
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
                        // 速度阈值，单位是点/秒
                        let velocityThreshold: CGFloat = 200
                        
                        if value.translation.width < -threshold || value.velocity.width < -velocityThreshold {
                            withAnimation {
                                currentIndex += 1
                                tempOffset = 0
                            }
                        } else if value.translation.width > threshold || value.velocity.width > velocityThreshold {
                            withAnimation {
                                currentIndex -= 1
                                tempOffset = 0
                            }
                        } else {
                            withAnimation {
                                tempOffset = 0
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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
            //.border(.red)
            
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



#Preview {
    let appState = AppState.shared
    let ads: [Ad] = [
        Ad(imageURL: "qwe"),
        Ad(imageURL: "qwe"),
        Ad(imageURL: "qwe")
    ]
    return AdsBannerView(width: 300, height: 200, ads: ads)
        .environmentObject(appState)
}
