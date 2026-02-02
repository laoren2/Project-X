//
//  FeedbackMailBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/9.
//
#if DEBUG
import SwiftUI


struct FeedbackMailBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = FeedbackMailBackendViewModel()
    
    var selectedMailID: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("反馈邮件")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            Spacer()
            
            Button("查询反馈邮件") {
                viewModel.mails.removeAll()
                viewModel.currentPage = 1
                viewModel.queryMails()
            }
            .padding()
            
            // 搜索结果展示，每条记录末尾添加一个"修改"按钮
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.mails) { mail in
                        FeedbackMailCardView(viewModel: viewModel, mail: mail)
                            .onAppear {
                                if mail == viewModel.mails.last && viewModel.hasMoreMails {
                                    viewModel.queryMails()
                                }
                            }
                    }
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top)
            }
            .background(.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .bottomSheet(isPresented: $viewModel.showMailDetail, size: .large, destroyOnDismiss: true) {
            FeedbackMailDetailView(viewModel: viewModel)
        }
    }
}

struct FeedbackMailCardView: View {
    @ObservedObject var viewModel: FeedbackMailBackendViewModel
    let mail: FeedbackMailInfo
    
    var body: some View {
        HStack {
            Text(mail.mailType.rawValue)
            Text(LocalizedStringKey(DateDisplay.formattedDate(mail.createdDate)))
            Spacer()
            Button("详情") {
                viewModel.selectedMail = mail
                viewModel.showMailDetail = true
            }
            Text(mail.isHandled ? "已处理" : "待处理")
                .foregroundStyle(mail.isHandled ? Color.green : Color.orange)
        }
    }
}

struct FeedbackMailDetailView: View {
    @ObservedObject var viewModel: FeedbackMailBackendViewModel
    @State var images: [UIImage] = []
    @State private var selectedImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        if let mail = viewModel.selectedMail {
            VStack {
                HStack {
                    Button("取消") {
                        viewModel.showMailDetail = false
                    }
                    Spacer()
                    Button("完成处理") {
                        viewModel.showMailDetail = false
                        viewModel.handleFeedback()
                    }
                }
                .padding()
                ScrollView(.vertical) {
                    VStack(spacing: 10) {
                        HStack {
                            Text("用户联系方式")
                            Spacer()
                        }
                        HStack {
                            if let contact = mail.userContactInfo {
                                Text(contact)
                            } else {
                                Text("无")
                            }
                        }
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        HStack {
                            Text("描述")
                            Spacer()
                        }
                        Text(mail.content)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                        HStack {
                            Text("截图")
                            Spacer()
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 150, height: 150)
                                        .onTapGesture {
                                            selectedImage = image
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color.white)
            .onFirstAppear {
                for imageURL in mail.images {
                    NetworkService.downloadImage(from: imageURL) { image in
                        if let image = image {
                            DispatchQueue.main.async {
                                self.images.append(image)
                            }
                        }
                    }
                }
            }
            .overlay(
                Group {
                    if let img = selectedImage {
                        Color.black.opacity(0.9)
                            .ignoresSafeArea()
                            .overlay(
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .simultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                scale = max(1.0, lastScale * value)
                                            }
                                            .onEnded { _ in
                                                lastScale = max(1.0, scale)
                                            }
                                    )
                                    .simultaneousGesture(
                                        DragGesture()
                                            .onChanged { value in
                                                if scale > 1.0 {
                                                    offset = CGSize(width: value.translation.width + lastOffset.width,
                                                                    height: value.translation.height + lastOffset.height)
                                                }
                                            }
                                            .onEnded { _ in
                                                if scale > 1.0 {
                                                    lastOffset = offset
                                                }
                                            }
                                    )
                                    .onTapGesture {
                                        selectedImage = nil
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                            )
                    }
                }
            )
        }
    }
}
#endif
