//
//  NewUserGuideView.swift
//  sportsx
//
//  新用户引导流程（注册后 isRegister 触发，全屏 overlay）。
//  5 阶段：欢迎 / 运动选择 / feature 介绍 / 个人资料 / 礼包发放。
//  顶部：跳过 + 上一步；中间：内容主体；底部：进度条(ProgressBar) + 下一步/完成。
//

import SwiftUI

struct NewUserGuideView: View {
    @ObservedObject var userManager = UserManager.shared

    @State private var stage: Int = 1
    private let totalStages = 5

    // 阶段2：运动选择（默认 bike）
    @State private var selectedSport: SportName = .Bike
    @State private var animatingSport: SportName? = nil

    // 阶段4：个人资料
    @State private var nickname: String = ""
    @State private var gender: Gender? = nil
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var isSubmittingProfile: Bool = false
    @State private var showGiftRewards: Bool = false
    @State private var animateFeatureIcons: Bool = false

    // 阶段5：礼包内容（与后端 distribute_newcomer_gift 保持一致）
    private struct GiftItem: Identifiable {
        let id = UUID()
        let type: CCAssetType
        let amount: Int
    }
    private let giftItems: [GiftItem] = [
        GiftItem(type: .coin, amount: 500),
        GiftItem(type: .stone1, amount: 10),
        GiftItem(type: .stone2, amount: 10),
        GiftItem(type: .stone3, amount: 10)
    ]

    var body: some View {
        ZStack {
            Color.defaultBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                if stage == 1 {
                    Spacer()
                    welcomeStage
                        .padding(.bottom, 150)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        stageContent
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                bottomBar
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 以已有资料预填（新用户通常为默认值）
            nickname = userManager.user.nickname
            gender = userManager.user.gender
            selectedSport = userManager.user.globalDefaultSport
        }
        .overlay {
            if stage == 1 {
                LottieView(
                    animationName: "confetti",
                    contentMode: .scaleAspectFill
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - 顶部栏：跳过 + 上一步
    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                if stage > 1 {
                    Button(action: { withAnimation { stage -= 1 } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("guide.action.previous")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.secondText)
                    }
                }
                Spacer()
                if stage != 1 && stage != 5 {
                    Button(action: { stage += 1 }) {
                        Text("guide.action.skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.secondText)
                    }
                }
            }
            .frame(height: 24)
            if stage > 1 {
                Divider()
            }
        }
    }

    // MARK: - 底部栏：进度条 + 下一步/完成
    private var bottomBar: some View {
        VStack(spacing: 16) {
            ProgressBar(progress: Double(stage) / Double(totalStages))
                .frame(height: 10)

            Button(action: { onNext() }) {
                Text(stage < totalStages ? "guide.action.next" : "guide.action.done")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(nextEnabled ? Color.orange : Color.gray)
                    .clipShape(Capsule())
            }
            .disabled(!nextEnabled)
        }
    }

    // 阶段4 需昵称非空 + 已选性别才能继续；其余阶段恒可继续
    private var nextEnabled: Bool {
        if isSubmittingProfile { return false }
        if stage == 4 {
            return !nickname.trimmingCharacters(in: .whitespaces).isEmpty && gender != nil
        }
        return true
    }

    // MARK: - 各阶段内容
    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case 1: welcomeStage
        case 2: sportSelectionStage
        case 3: featureIntroStage
        case 4: profileStage
        default: giftStage
        }
    }

    // 阶段1：欢迎
    private var welcomeStage: some View {
        VStack(alignment: .center, spacing: 20) {
            Image("single_app_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 90)
                .foregroundStyle(Color.orange)
            Text("guide.stage1.title")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.white)
            Text("guide.stage1.content")
                .font(.system(size: 20))
                .foregroundStyle(Color.secondText)
                .lineSpacing(4)
        }
        .padding()
    }

    // 阶段2：运动选择
    private var sportSelectionStage: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("guide.stage2.title")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white)
            HStack(spacing: 16) {
                sportCard(.Bike)
                sportCard(.Running)
            }
            Text("guide.stage2.note")
                .font(.system(size: 14))
                .foregroundStyle(Color.thirdText)
        }
    }

    private func sportCard(_ sport: SportName) -> some View {
        let isSelected = selectedSport == sport
        return VStack(spacing: 12) {
            Image(sport.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 50)
                .rotationEffect(
                    .degrees(animatingSport == sport ? 12 : 0)
                )
                .scaleEffect(animatingSport == sport ? 1.1 : 1.0)
                .animation(
                    .spring(response: 0.15, dampingFraction: 0.45)
                        .repeatCount(1, autoreverses: true),
                    value: animatingSport == sport
                )
            Text(LocalizedStringKey(sport.name))
                .font(.system(size: 18, weight: .semibold))
        }
        .foregroundStyle(isSelected ? Color.white : Color.secondText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.secondBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
        )
        .cornerRadius(16)
        .exclusiveTouchTapGesture {
            selectedSport = sport
            animatingSport = sport

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if animatingSport == sport {
                    animatingSport = nil
                }
            }
        }
    }

    // 阶段3：feature 介绍
    private var featureIntroStage: some View {
        VStack(alignment: .center, spacing: 50) {
            Text("guide.stage3.title")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white)
            ForEach(SportFeature.features(for: selectedSport)) { feature in
                ZStack(alignment: .topTrailing) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(feature.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.white)
                            Text(LocalizedStringKey(featureDescKey(feature)))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondText)
                                .lineSpacing(2)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.secondBackground)
                    .cornerRadius(12)
                    
                    Image(featureIcon(feature))
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundStyle(Color.orange)
                        .rotationEffect(.degrees(animateFeatureIcons ? -6 : 8))
                        .scaleEffect(animateFeatureIcons ? 1.05 : 1.0)
                        .offset(y: -30)
                        .animation(
                            .easeInOut(duration: 0.18)
                            .repeatCount(1, autoreverses: true),
                            value: animateFeatureIcons
                        )
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateFeatureIcons = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                animateFeatureIcons = false
            }
        }
    }

    private func featureDescKey(_ f: SportFeature) -> String {
        switch f.featureType {
        case .race: return "guide.feature.race.desc"
        case .freeTraining: return "guide.feature.free_training.desc"
        case .routeTraining: return "guide.feature.route_training.desc"
        }
    }
    
    private func featureIcon(_ f: SportFeature) -> String {
        switch f.featureType {
        case .race: return "leaderboard"
        case .freeTraining: return "grid_guide"
        case .routeTraining: return "magiccard"
        }
    }

    // 阶段4：个人资料
    private var profileStage: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("guide.stage4.title")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white)

            // 昵称
            VStack(alignment: .leading, spacing: 8) {
                Text("guide.stage4.nickname")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white)
                TextField(text: $nickname) {
                    Text("guide.stage4.nickname.placeholder")
                        .foregroundStyle(Color.thirdText)
                }
                .foregroundStyle(Color.white)
                .padding()
                .background(Color.secondBackground)
                .cornerRadius(10)
                .onValueChange(of: nickname) { _, newState in
                    if newState.count > 20 {
                        nickname = String(newState.prefix(20))
                    }
                }
            }

            // 性别
            VStack(alignment: .leading, spacing: 8) {
                Text("guide.stage4.gender")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white)
                HStack(spacing: 12) {
                    genderCard(.male)
                    genderCard(.female)
                }
                Text("guide.stage4.gender.note")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pink)
            }

            // 生日
            VStack(alignment: .leading, spacing: 8) {
                Text("guide.stage4.birthday")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white)
                DatePicker(
                    "",
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func genderCard(_ g: Gender) -> some View {
        let isSelected = gender == g
        return HStack(spacing: 6) {
            Image(g.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(isSelected ? (g == .male ? Color.blue : Color.pink) : Color.white)
            Text(LocalizedStringKey(g.displayName))
                .font(.system(size: 16, weight: .medium))
        }
        .foregroundStyle(isSelected ? Color.white : Color.secondText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
        )
        .cornerRadius(10)
        .exclusiveTouchTapGesture {
            gender = g
        }
    }

    // 阶段5：礼包发放
    private var giftStage: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("guide.stage5.title")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white)
            LottieView(
                animationName: "giftbox_open",
                holdOnLastFrame: true,
                stopAtProgress: 0.6
            )
            .frame(height: 200)
            if showGiftRewards {
                VStack(spacing: 12) {
                    ForEach(giftItems) { item in
                        HStack(spacing: 12) {
                            Image(item.type.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            Text("x\(item.amount)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .transition(.opacity)

                Text("guide.stage5.distributed")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.green)
                    .transition(.opacity)
            }
        }
        .onAppear {
            showGiftRewards = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showGiftRewards = true
                }
            }
        }
    }

    // MARK: - 交互

    private func onNext() {
        switch stage {
        case 2:
            commitGlobalDefaultSport() { success in
                if success {
                    DispatchQueue.main.async { withAnimation { stage = 3 } }
                }
            }
            //withAnimation { stage = 3 }
        case 4:
            submitProfile { success in
                if success {
                    DispatchQueue.main.async { withAnimation { stage = 5 } }
                }
            }
            //withAnimation { stage = 5 }
        case totalStages:
            close()
        default:
            withAnimation { stage += 1 }
        }
    }

    private func close() {
        withAnimation { userManager.showingGuide = false }
    }

    // 提交全局默认运动，同步播种运动中心
    private func commitGlobalDefaultSport(completion: @escaping (Bool) -> Void) {
        guard var components = URLComponents(string: "/user/update_global_default_sport") else { return }
        components.queryItems = [URLQueryItem(name: "sport", value: selectedSport.rawValue)]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: SportName.self, showLoadingToast: true, showErrorToast: true) { result in
            if case .success(let data) = result, let value = data {
                DispatchQueue.main.async {
                    userManager.user.globalDefaultSport = value
                    UserDefaults.standard.set(value.rawValue, forKey: "user.globalDefaultSport")
                    AppState.shared.sportFeature = SportFeature.defaultFeature(for: value)
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }

    // 提交昵称/性别/生日（复用 /user/update，展示开关沿用当前值）
    private func submitProfile(completion: @escaping (Bool) -> Void) {
        isSubmittingProfile = true
        let boundary = "Boundary-\(UUID().uuidString)"
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let birthdayStr = formatter.string(from: birthDate)
        let u = userManager.user

        let textFields: [String: String?] = [
            "nickname": nickname.trimmingCharacters(in: .whitespaces),
            "introduction": u.introduction,
            "location": u.location,
            "gender": gender?.rawValue,
            "birthday": birthdayStr,
            "is_display_gender": u.isDisplayGender.description,
            "is_display_age": u.isDisplayAge.description,
            "is_display_location": u.isDisplayLocation.description,
            "enable_auto_location": u.enableAutoLocation.description,
            "is_display_identity": u.isDisplayIdentity.description
        ]

        var body = Data()
        for (key, value) in textFields {
            if let unwrapped = value {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.append("\(unwrapped)\r\n")
            }
        }
        body.append("--\(boundary)--\r\n")

        let request = APIRequest(path: "/user/update", method: .post, headers: headers, body: body, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: FetchBaseUserResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let user = data?.user {
                    DispatchQueue.main.async {
                        userManager.user.nickname = user.nickname
                        userManager.user.gender = user.gender
                        userManager.user.birthday = user.birthday
                        userManager.saveUserInfoToCache()
                        isSubmittingProfile = false
                    }
                    completion(true)
                } else {
                    DispatchQueue.main.async { isSubmittingProfile = false }
                    completion(false)
                }
            default:
                DispatchQueue.main.async { isSubmittingProfile = false }
                completion(false)
            }
        }
    }
}

#Preview {
    NewUserGuideView()
}
