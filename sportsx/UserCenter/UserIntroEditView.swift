//
//  UserIntroEditView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/24.
//

import SwiftUI
import PhotosUI


struct UserIntroEditView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = UserIntroEditViewModel()
    
    @State private var showAvatarPicker = false
    @State private var showBackgroundPicker = false
    
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedBackgroundItem: PhotosPickerItem?
    
    @State private var showNameEditor = false
    @State private var showIntroEditor = false
    @State private var showGenderEditor = false
    @State private var showAgeEditor = false
    @State private var showLocationEditor = false
    @State private var showIdentityEditor = false
    
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            viewModel.backgroundColor.softenColor(blendWithWhiteRatio: 0.2),
                            viewModel.backgroundColor
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        // 封面
                        if let background = viewModel.backgroundImage {
                            Image(uiImage: background)
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                .cornerRadius(20)
                        } else {
                            Image("Ads")
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width - 32, height: 200)
                                .cornerRadius(20)
                        }
                        
                        // 头像更换区
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottom) {
                                if let avatar = viewModel.avatarImage {
                                    Image(uiImage: avatar)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .foregroundStyle(.blue)
                                        .clipShape(Circle())
                                }
                                
                                Button(action: {
                                    showAvatarPicker = true
                                }) {
                                    Text("更换头像")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(15)
                                        .offset(y: 10)
                                }
                            }
                            .padding(.top, 30)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, -25)
                    }
                    .padding(.bottom, 50)
                    //.border(.red)
                    
                    // 资料编辑表单
                    VStack(spacing: 0) {
                        // 名字
                        EditItemView(title: "名字", value: viewModel.currentUser.nickname) {
                            showNameEditor = true
                        }
                        
                        // 简介
                        EditItemView(title: "简介", value: viewModel.currentUser.introduction ?? "") {
                            showIntroEditor = true
                        }
                        
                        // 性别
                        EditItemView(title: "性别", value: viewModel.currentUser.gender ?? "未设置") {
                            showGenderEditor = true
                        }
                        
                        // 生日
                        EditItemView(title: "生日", value: viewModel.currentUser.birthday ?? "未设置") {
                            showAgeEditor = true
                        }
                        
                        // 所在地
                        EditItemView(title: "所在地", value: viewModel.currentUser.location ?? "未设置") {
                            showLocationEditor = true
                        }
                        
                        // 学校
                        EditItemView(title: "身份认证", value: viewModel.currentUser.identityAuthName ?? "未认证") {
                            showIdentityEditor = true
                        }
                    }
                    .cornerRadius(20)
                    .padding()
                    
                    Button(action: {
                        viewModel.saveMeInfo()
                    }) {
                        Text("保存")
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .foregroundStyle(.white)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            //.border(.red)
                    }
                    .padding(.bottom, 80)
                }
                .padding(.top, 56)
                //.border(.green)
            }
            //.border(.red)
            
            // 顶部导航栏
            HStack(alignment: .center) {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button(action: {
                    showBackgroundPicker = true
                }) {
                    Text("更换封面")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 15)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            .frame(height: 40)
            //.border(.red)
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture(true)
        .sheet(isPresented: $showIntroEditor) {
            IntroEditorView(viewModel: viewModel, showIntroEditor: $showIntroEditor)
                .presentationDetents([.fraction(0.5)])
                .interactiveDismissDisabled() // 防止点击过快导致弹窗高度错误
        }
        .sheet(isPresented: $showNameEditor) {
            NameEditorView(viewModel: viewModel, showNameEditor: $showNameEditor)
                .presentationDetents([.fraction(0.3)])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showGenderEditor) {
            GenderEditorView(viewModel: viewModel, showGenderEditor: $showGenderEditor)
                .presentationDetents([.fraction(0.3)])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showAgeEditor) {
            AgeEditorView(viewModel: viewModel, showAgeEditor: $showAgeEditor)
                .presentationDetents([.fraction(0.3)])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showLocationEditor) {
            LocationEditorView(viewModel: viewModel, showLocationEditor: $showLocationEditor)
                .presentationDetents([.fraction(0.3)])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showIdentityEditor) {
            IdentityEditorView(viewModel: viewModel, showIdentityEditor: $showIdentityEditor)
                .presentationDetents([.fraction(0.3)])
                .interactiveDismissDisabled()
        }
        .photosPicker(isPresented: $showAvatarPicker, selection: $selectedAvatarItem, matching: .images)
        .photosPicker(isPresented: $showBackgroundPicker, selection: $selectedBackgroundItem, matching: .images)
        .onChange(of: selectedAvatarItem) {
            Task {
                if let data = try? await selectedAvatarItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    viewModel.avatarImage = uiImage
                } else {
                    viewModel.avatarImage = nil
                }
            }
        }
        .onChange(of: selectedBackgroundItem) {
            Task {
                if let data = try? await selectedBackgroundItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    viewModel.backgroundImage = uiImage
                } else {
                    viewModel.backgroundImage = nil
                }
            }
        }
        .onChange(of: viewModel.backgroundImage) {
            if let backgroundImage = viewModel.backgroundImage, let avg = ImageTool.averageColor(from: backgroundImage) {
                viewModel.backgroundColor = avg.bestSoftDarkReadableColor()
            } else {
                viewModel.backgroundColor = .defaultBackground
            }
        }
    }
}

struct EditItemView: View {
    let title: String
    let value: String
    let onEdit: (() -> Void)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.secondText)
                    .frame(width: 80, alignment: .leading)
                
                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 15)
            .padding(.horizontal)
            
            Divider()
                .padding(.leading, 80)
        }
        .background(.ultraThinMaterial)
        .onTapGesture {
            onEdit()
        }
    }
}

struct IntroEditorView: View {
    @ObservedObject var viewModel: UserIntroEditViewModel
    @Binding var showIntroEditor: Bool
    @State private var tempIntro: String = ""
    
    var body: some View {
        ZStack {
            viewModel.backgroundColor
                .opacity(0.9)
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    HStack {
                        Button(action: {
                            showIntroEditor = false
                        }) {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                        
                        Spacer()
                        
                        Button(action:{
                            viewModel.currentUser.introduction = tempIntro
                            showIntroEditor = false
                        }) {
                            Text("完成")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.vertical)
                    
                    Text("编辑简介")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                TextEditor(text: $tempIntro)
                    .padding()
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .onChange(of: tempIntro) {
                        DispatchQueue.main.async {
                            if tempIntro.count > 100 {
                                tempIntro = String(tempIntro.prefix(100)) // 限制为最多100个字符
                            }
                        }
                    }
                    //.border(.green)
                
                HStack {
                    Text("最多输入100个字符")
                        .font(.footnote)
                        .foregroundStyle(Color.secondText)
                    
                    Spacer()
                    
                    Text("已输入\(tempIntro.count)/100字符")
                        .font(.footnote)
                        .foregroundStyle(Color.secondText)
                }
                .padding(.horizontal)
            }
            .padding(.horizontal)
            //.border(.red)
        }
        .onAppear {
            tempIntro = viewModel.currentUser.introduction ?? ""
        }
    }
}

struct NameEditorView: View {
    @ObservedObject var viewModel: UserIntroEditViewModel
    @Binding var showNameEditor: Bool
    @State private var tempName: String = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            viewModel.backgroundColor
                .opacity(0.9)
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    HStack {
                        Button(action: {
                            showNameEditor = false
                        }) {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                        
                        Spacer()
                        
                        Button(action:{
                            viewModel.currentUser.nickname = tempName
                            showNameEditor = false
                        }) {
                            Text("完成")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.vertical)
                    
                    Text("编辑名字")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                TextField(tempName, text: $tempName)
                    .padding()
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .onChange(of: tempName) {
                        DispatchQueue.main.async {
                            if tempName.count > 10 {
                                tempName = String(tempName.prefix(10)) // 限制为最多10个字符
                            }
                        }
                    }
                
                HStack {
                    Text("最多输入10个字符")
                        .font(.footnote)
                        .foregroundStyle(Color.secondText)
                    
                    Spacer()
                    
                    Text("已输入\(tempName.count)/10字符")
                        .font(.footnote)
                        .foregroundStyle(Color.secondText)
                }
                .padding(.vertical)
            }
            .padding(.horizontal)
        }
        .onAppear {
            tempName = viewModel.currentUser.nickname
        }
    }
}

struct GenderEditorView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserIntroEditViewModel
    @Binding var showGenderEditor: Bool
    @State private var tempDisplayStatus: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            viewModel.backgroundColor
                .opacity(0.9)
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    HStack {
                        Button(action: {
                            showGenderEditor = false
                        }) {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                        
                        Spacer()
                        
                        Button(action:{
                            viewModel.currentUser.isDisplayGender = tempDisplayStatus
                            showGenderEditor = false
                        }) {
                            Text("完成")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.vertical)
                    
                    Text("编辑性别")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                VStack{
                    Toggle("展示", isOn: $tempDisplayStatus)
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                        .disabled(!viewModel.currentUser.isRealnameAuth)
                    
                    Divider()
                    
                    HStack {
                        Text("实名认证信息中的性别")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if viewModel.currentUser.isRealnameAuth {
                            Text("\(viewModel.currentUser.gender ?? "未知")")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        } else {
                            Text("去认证")
                                .font(.system(size: 14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(.pink)
                                .cornerRadius(10)
                                .onTapGesture {
                                    appState.navigationManager.append(.realNameAuthView)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            tempDisplayStatus = viewModel.currentUser.isDisplayGender
        }
    }
}

struct AgeEditorView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserIntroEditViewModel
    @Binding var showAgeEditor: Bool
    @State private var tempDisplayStatus: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            viewModel.backgroundColor
                .opacity(0.9)
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    HStack {
                        Button(action: {
                            showAgeEditor = false
                        }) {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                        
                        Spacer()
                        
                        Button(action:{
                            viewModel.currentUser.isDisplayAge = tempDisplayStatus
                            showAgeEditor = false
                        }) {
                            Text("完成")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.vertical)
                    
                    Text("编辑生日")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                VStack{
                    Toggle("展示", isOn: $tempDisplayStatus)
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                        .disabled(!viewModel.currentUser.isRealnameAuth)
                    
                    Divider()
                    
                    HStack {
                        Text("实名认证信息中的出生日期")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if viewModel.currentUser.isRealnameAuth {
                            Text("\(viewModel.currentUser.birthday ?? "未知")")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        } else {
                            Text("去认证")
                                .font(.system(size: 14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(.pink)
                                .cornerRadius(10)
                                .onTapGesture {
                                    appState.navigationManager.append(.realNameAuthView)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            tempDisplayStatus = viewModel.currentUser.isDisplayAge
        }
    }
}

struct LocationEditorView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserIntroEditViewModel
    @Binding var showLocationEditor: Bool
    @State private var tempDisplayStatus: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            viewModel.backgroundColor
                .opacity(0.9)
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    HStack {
                        Button(action: {
                            showLocationEditor = false
                        }) {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                        
                        Spacer()
                        
                        Button(action:{
                            viewModel.currentUser.isDisplayLocation = tempDisplayStatus
                            showLocationEditor = false
                        }) {
                            Text("完成")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.vertical)
                    
                    Text("编辑位置")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                
                VStack(spacing: 5) {
                    Toggle("展示", isOn: $tempDisplayStatus)
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                        .frame(height: 40)
                    
                    Divider()
                    
                    Toggle("自动更新位置", isOn: $viewModel.currentUser.enableAutoLocation)
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                        .frame(height: 40)
                    
                    Divider()
                    
                    HStack {
                        Text("地理位置")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if appState.config.location != viewModel.currentUser.location {
                            HStack(spacing: 0) {
                                Image(systemName: "location")
                                    .font(.system(size: 14))
                                Text("当前位置")
                                    .font(.system(size: 14))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .foregroundStyle(.white)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .onTapGesture {
                                viewModel.currentUser.location = appState.config.location
                            }
                            .border(.green)
                        }
                        
                        Text("\(viewModel.currentUser.location ?? "未设置")")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .frame(height: 40)
                    .border(.red)
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            tempDisplayStatus = viewModel.currentUser.isDisplayLocation
        }
    }
}

struct IdentityEditorView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserIntroEditViewModel
    @Binding var showIdentityEditor: Bool
    @State private var tempDisplayStatus: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            viewModel.backgroundColor
                .opacity(0.9)
                .ignoresSafeArea()
            
            VStack {
                ZStack {
                    HStack {
                        Button(action: {
                            showIdentityEditor = false
                        }) {
                            Text("取消")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                        
                        Spacer()
                        
                        Button(action:{
                            viewModel.currentUser.isDisplayIdentity = tempDisplayStatus
                            showIdentityEditor = false
                        }) {
                            Text("完成")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    .padding(.vertical)
                    
                    Text("编辑身份")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                VStack{
                    Toggle("展示", isOn: $tempDisplayStatus)
                        .foregroundStyle(.white)
                        .font(.system(size: 16))
                        .disabled(!viewModel.currentUser.isIdentityAuth)
                    
                    Divider()
                    
                    HStack {
                        Text("已认证的身份信息")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if viewModel.currentUser.isIdentityAuth {
                            Text("\(viewModel.currentUser.identityAuthName ?? "未认证")")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        } else {
                            Text("去认证")
                                .font(.system(size: 14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(.pink)
                                .cornerRadius(10)
                                .onTapGesture {
                                    appState.navigationManager.append(.identityAuthView)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            tempDisplayStatus = viewModel.currentUser.isDisplayIdentity
        }
    }
}

#Preview {
    let appState = AppState.shared
    let viewModel = UserIntroEditViewModel()
    viewModel.currentUser.introduction = "sdsdjsnkjfskjgdkfdlkfjsklfjdklfjdklsdsd"
    
    return UserIntroEditView(viewModel: viewModel)
        .environmentObject(appState)
}
