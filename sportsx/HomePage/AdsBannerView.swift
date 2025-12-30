//
//  AdsBannerView.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/3.
//

import SwiftUI
import Combine

struct AdsCard: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    
    let width: CGFloat
    let height: CGFloat
    let image: String?
    let imageLocal: String?
    let route: AppRoute?
    var body: some View {
        if let url = image {
            CachedAsyncImage(
                urlString: url,
                placeholder: Image("Ads"),
                errorImage: Image(systemName: "photo.badge.exclamationmark")
            )
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
        } else if let localURL = imageLocal {
            Image(localURL)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .exclusiveTouchTapGesture {
                    if let desRoute = route {
                        navigationManager.append(desRoute)
                    }
                }
        } else {
            Image("Ads")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
        }
    }
}

struct AdsBannerView: View {
    @EnvironmentObject var appState: AppState
    
    var width: CGFloat
    var height: CGFloat
    
    @State var ads: [AdInfo]
    @State var currentIndex = 1
    @State private var cancellable: AnyCancellable? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            HorizontalScrollView(
                currentIndex: $currentIndex,
                adsCount: ads.count,
                width: width,
                onScrollWillBegin: {
                    if cancellable != nil {
                        stopAutoScroll()
                    }
                },
                onScrollDidEnd: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        startAutoScroll()
                    }
                }
            ) {
                // 添加一个重复的最后一页用于无限循环
                AdsCard(width: width, height: height, image: ads.last?.imageURL, imageLocal: ads.last?.imageLocalURL, route: ads.last?.appRoute)
                    //.frame(width: width, height: height)
                
                ForEach(ads.indices, id: \.self) { index in
                    AdsCard(width: width, height: height, image: ads[index].imageURL, imageLocal: ads[index].imageLocalURL, route: ads[index].appRoute)
                        //.frame(width: width, height: height)
                }
                // 添加一个重复的第一页用于无限循环
                AdsCard(width: width, height: height, image: ads.first?.imageURL, imageLocal: ads.first?.imageLocalURL, route: ads.first?.appRoute)
                    //.frame(width: width, height: height)
            }
            .frame(width: width, height: height)
            
            // 分页指示器
            HStack(spacing: 8) {
                ForEach(ads.indices, id: \.self) { index in
                    Circle()
                        .fill(index + 1 == currentIndex ? Color.white : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 10)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onStableAppear() {
            startAutoScroll()
        }
        .onStableDisappear {
            stopAutoScroll()
        }
    }
    
    // 开始自动滚动
    func startAutoScroll() {
        guard ads.count > 0 else { return }
        
        // 如果 Timer 已经存在，则不再创建新的 Timer
        if cancellable != nil {
            return
        }
        // 创建一个 Timer Publisher，每隔3秒发送一次事件
        cancellable = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentIndex += 1
            }
    }
    
    // 停止自动滚动
    func stopAutoScroll() {
        cancellable?.cancel()
        cancellable = nil
    }
}

struct HorizontalScrollView<Content: View>: UIViewRepresentable {
    @Binding var currentIndex: Int
    let adsCount: Int
    let width: CGFloat
    let onScrollWillBegin: (() -> Void)?
    let onScrollDidEnd: (() -> Void)?
    let content: () -> Content

    init(
        currentIndex: Binding<Int>,
        adsCount: Int,
        width: CGFloat,
        onScrollWillBegin: (() -> Void)? = nil,
        onScrollDidEnd: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._currentIndex = currentIndex
        self.adsCount = adsCount
        self.width = width
        self.onScrollWillBegin = onScrollWillBegin
        self.onScrollDidEnd = onScrollDidEnd
        self.content = content
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.tag = 99

        let hostingController = UIHostingController(rootView: HStack(spacing: 0, content: content))
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostingController.view.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        // 初始滚动到 currentIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollView.contentOffset.x = CGFloat(currentIndex) * width
            context.coordinator.islayoutFinished = true
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let expectedOffset = CGFloat(currentIndex) * width
        if abs(uiView.contentOffset.x - expectedOffset) > 1 {
            uiView.setContentOffset(CGPoint(x: expectedOffset, y: 0), animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: HorizontalScrollView
        var islayoutFinished = false

        init(_ parent: HorizontalScrollView) {
            self.parent = parent
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.onScrollWillBegin?()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard islayoutFinished else { return }
            let offsetX = scrollView.contentOffset.x
            let pageWidth = parent.width
            let totalPages = parent.adsCount + 2 // 多加首尾

            // 如果滑到最前面（第0页），跳转到倒数第1页（adsCount页）
            if offsetX <= 0 {
                scrollView.setContentOffset(CGPoint(x: CGFloat(parent.adsCount) * pageWidth, y: 0), animated: false)
                DispatchQueue.main.async {
                    self.parent.currentIndex = self.parent.adsCount
                }
            }
            // 如果滑到最后一页（adsCount+1），跳转到第一页（index 1）
            else if offsetX >= CGFloat(totalPages - 1) * pageWidth {
                scrollView.setContentOffset(CGPoint(x: pageWidth, y: 0), animated: false)
                DispatchQueue.main.async {
                    self.parent.currentIndex = 1
                }
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                parent.onScrollDidEnd?()
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let page = Int((scrollView.contentOffset.x / parent.width).rounded())
            DispatchQueue.main.async {
                if page == 0 {
                    self.parent.currentIndex = self.parent.adsCount
                    scrollView.setContentOffset(CGPoint(x: CGFloat(self.parent.adsCount) * self.parent.width, y: 0), animated: false)
                } else if page == self.parent.adsCount + 1 {
                    self.parent.currentIndex = 1
                    scrollView.setContentOffset(CGPoint(x: self.parent.width, y: 0), animated: false)
                } else {
                    self.parent.currentIndex = page
                }
                self.parent.onScrollDidEnd?()
            }
        }
        
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            let page = Int((scrollView.contentOffset.x / parent.width).rounded())
            if page == parent.adsCount + 1 {
                DispatchQueue.main.async {
                    self.parent.currentIndex = 1
                }
                scrollView.setContentOffset(CGPoint(x: parent.width, y: 0), animated: false)
            }
        }
    }
}

struct TextCard: View {
    //let width: CGFloat
    let height: CGFloat
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(/*width: width, */height: height, alignment: .leading)
            .padding(.horizontal, 12)
            //.background(Color.black.opacity(0.4))
    }
}

struct TextBannerView: View {
    //let width: CGFloat
    let height: CGFloat
    let texts: [String]

    @State private var currentIndex: Int = 1
    @State private var cancellable: AnyCancellable?

    var body: some View {
        ZStack {
            VerticalScrollView(
                currentIndex: $currentIndex,
                itemCount: texts.count,
                height: height,
                onScrollWillBegin: {
                    stopAutoScroll()
                },
                onScrollDidEnd: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        startAutoScroll()
                    }
                }
            ) {
                // 尾部复制页
                HStack {
                    TextCard(
                        //width: width,
                        height: height,
                        text: texts.last ?? ""
                    )
                    Spacer()
                }

                ForEach(texts.indices, id: \.self) { index in
                    HStack {
                        TextCard(
                            //width: width,
                            height: height,
                            text: texts[index]
                        )
                        Spacer()
                    }
                }

                // 头部复制页
                HStack {
                    TextCard(
                        //width: width,
                        height: height,
                        text: texts.first ?? ""
                    )
                    Spacer()
                }
            }
            .frame(/*width: width, */height: height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    // MARK: - Auto Scroll

    func startAutoScroll() {
        guard texts.count > 0 else { return }
        if cancellable != nil { return }

        cancellable = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentIndex += 1
            }
    }

    func stopAutoScroll() {
        cancellable?.cancel()
        cancellable = nil
    }
}

struct VerticalScrollView<Content: View>: UIViewRepresentable {
    @Binding var currentIndex: Int
    let itemCount: Int
    let height: CGFloat
    let onScrollWillBegin: (() -> Void)?
    let onScrollDidEnd: (() -> Void)?
    let content: () -> Content
    

    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        height: CGFloat,
        onScrollWillBegin: (() -> Void)? = nil,
        onScrollDidEnd: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._currentIndex = currentIndex
        self.itemCount = itemCount
        self.height = height
        self.onScrollWillBegin = onScrollWillBegin
        self.onScrollDidEnd = onScrollDidEnd
        self.content = content
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isPagingEnabled = true
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = context.coordinator

        let hosting = UIHostingController(
            rootView: VStack(spacing: 0, content: content)
        )
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear

        scrollView.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        // todo: 优化这里的 hack
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollView.setContentOffset(
                CGPoint(x: 0, y: CGFloat(self.currentIndex) * self.height),
                animated: false
            )
            context.coordinator.islayoutFinished = true
        }
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let expectedOffset = CGFloat(currentIndex) * height
        if abs(uiView.contentOffset.y - expectedOffset) > 1 {
            //print(uiView.contentOffset.y, expectedOffset)
            uiView.setContentOffset(
                CGPoint(x: 0, y: expectedOffset),
                animated: true
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: VerticalScrollView
        var islayoutFinished = false
        
        init(_ parent: VerticalScrollView) {
            self.parent = parent
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            parent.onScrollWillBegin?()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard islayoutFinished else { return }
            let offsetY = scrollView.contentOffset.y
            let pageHeight = parent.height
            let totalPages = parent.itemCount + 2
            if offsetY <= 0 {
                scrollView.setContentOffset(
                    CGPoint(x: 0, y: CGFloat(parent.itemCount) * pageHeight),
                    animated: false
                )
                DispatchQueue.main.async {
                    self.parent.currentIndex = self.parent.itemCount
                }
            } else if offsetY >= CGFloat(totalPages - 1) * pageHeight {
                scrollView.setContentOffset(
                    CGPoint(x: 0, y: pageHeight),
                    animated: false
                )
                DispatchQueue.main.async {
                    self.parent.currentIndex = 1
                }
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let page = Int((scrollView.contentOffset.y / parent.height).rounded())
            DispatchQueue.main.async {
                if page == 0 {
                    self.parent.currentIndex = self.parent.itemCount
                } else if page == self.parent.itemCount + 1 {
                    self.parent.currentIndex = 1
                } else {
                    self.parent.currentIndex = page
                }
                self.parent.onScrollDidEnd?()
            }
        }
    }
}

