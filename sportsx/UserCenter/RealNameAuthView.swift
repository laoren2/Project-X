//
//  RealNameAuthView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/29.
//

import SwiftUI
import PhotosUI


struct RealNameAuthView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    
    @State var cardImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    @State var selectedCountry: Country? = nil
    @State var selectedAuthMethod: RealNameMethod? = nil
    @State var showCountrySheet: Bool = false
    @State var showMethodSheet: Bool = false
    
    
    init() {
        selectedCountry = LocationManager.shared.country
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondText)
                
                Spacer()
                
                Text("user.setup.realname_auth")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.secondText)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            HStack {
                if userManager.user.isRealnameAuth {
                    Text("user.setup.realname_auth.done")
                        .font(.title3)
                        .foregroundStyle(Color.green)
                } else {
                    Text("user.setup.realname_auth.undone")
                        .font(.title3)
                        .foregroundStyle(Color.gray)
                }
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.secondText)
                    .exclusiveTouchTapGesture {
                        PopupWindowManager.shared.presentPopup(
                            title: "user.setup.realname_auth",
                            bottomButtons: [
                                .confirm("action.confirm")
                            ]
                        ) {
                            JustifiedText("user.setup.realname_auth.popup", font: .systemFont(ofSize: 15), textColor: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1))
                        }
                    }
                Spacer()
            }
            
            Text("user.setup.realname_auth.content")
                .font(.caption)
                .foregroundStyle(Color.thirdText)
                .padding(.bottom, 50)
            
            VStack(spacing: 0) {
                SetUpItemView(icon: "person.text.rectangle", title: "user.setup.realname_auth.region", showChevron: true) {
                    showCountrySheet = true
                } trailingView: {
                    HStack(spacing: 4) {
                        if let country = selectedCountry {
                            Text(country.displayName)
                        } else {
                            Text("action.select")
                        }
                    }
                    .foregroundStyle(Color.thirdText)
                    .font(.subheadline)
                }
                
                SetUpItemView(icon: "person.text.rectangle", title: "user.setup.realname_auth.method", showChevron: true, showDivider: false) {
                    if selectedCountry != nil {
                        showMethodSheet = true
                    }
                } trailingView: {
                    HStack(spacing: 4) {
                        if let method = selectedAuthMethod {
                            Text(method.displayName)
                        } else {
                            Text("action.select")
                        }
                    }
                    .foregroundStyle(Color.thirdText)
                    .font(.subheadline)
                }
            }
            .cornerRadius(20)
            
            if selectedCountry != nil && selectedAuthMethod != nil {
                if let image = cardImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .onTapGesture {
                            showImagePicker = true
                        }
                } else {
                    EmptyCardSlot(text: "user.setup.realname_auth.upload", ratio: 7/5)
                        .frame(height: 150)
                        .onTapGesture {
                            showImagePicker = true
                        }
                }
            }
            
            Text("user.setup.realname_auth.content.2")
                .font(.caption)
                .foregroundStyle(Color.thirdText)
            
            Text(userManager.user.isRealnameAuth ? "user.setup.realname_auth.action.reauth" : "user.setup.realname_auth.action.auth")
                .font(.headline)
                .foregroundStyle(Color.white)
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(cardImage == nil ? Color.gray : Color.orange)
                .cornerRadius(10)
                .padding(.top, 20)
                .onTapGesture {
                    appliedOCR()
                }
                .disabled(cardImage == nil)
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    cardImage = uiImage
                } else {
                    cardImage = nil
                }
            }
        }
        .sheet(isPresented: $showCountrySheet) {
            CountryAuthView(selectedCountry: $selectedCountry)
                .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showMethodSheet) {
            if let country = selectedCountry {
                RealnameMethodView(selectedMethod: $selectedAuthMethod, country: country)
                    .presentationDetents([.fraction(0.4)])
            }
        }
    }
    
    func appliedOCR() {
        guard cardImage != nil, let country = selectedCountry, let method = selectedAuthMethod else { return }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        var body = Data()
        
        // 文字字段
        let textFields: [String: String?] = [
            "country_code": country.rawValue,
            "method": method.rawValue
        ]
        for (key, value) in textFields {
            if let unwrapped = value {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.append("\(unwrapped)\r\n")
            }
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("front_image", cardImage, "id_card.jpg")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 300) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/user/realname", method: .post, headers: headers, body: body, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "user.setup.realname_auth.toast.success"))
                }
                Task {
                    await UserManager.shared.fetchMeInfo()
                }
            default: break
            }
        }
    }
}

struct CountryAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCountry: Country?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Country.allCases.filter({ $0.supported }), id: \.self) { country in
                    Button {
                        selectedCountry = country
                        dismiss()
                    } label: {
                        HStack {
                            Text(country.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedCountry == country {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("user.setup.realname_auth.region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.close") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct RealnameMethodView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedMethod: RealNameMethod?
    
    let country: Country
    
    var body: some View {
        NavigationView {
            List {
                ForEach(country.realnameMethod, id: \.self) { method in
                    Button {
                        selectedMethod = method
                        dismiss()
                    } label: {
                        HStack {
                            HStack(alignment: .center, spacing: 4) {
                                Text(method.displayName)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            if selectedMethod == method {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("user.setup.realname_auth.method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.close") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}


#Preview {
    let appState = AppState.shared
    RealNameAuthView()
        .environmentObject(appState)
}
