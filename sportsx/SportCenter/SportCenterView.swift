//
//  SportCenterView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/5.
//

import SwiftUI
import MapKit


struct SportCenterView: View {
    @StateObject var viewModel = CompetitionCenterViewModel()
    
    var body: some View {
        // todo: 实现训练中心
        ZStack(alignment: .topLeading) {
            //TrainingCenterView()
            CompetitionCenterView(viewModel: viewModel)
                //.opacity(appState.navigationManager.isTrainingView ? 0 : 1)
        }
    }
}

struct CompetitionCenterView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: CompetitionCenterViewModel
    @ObservedObject var assetManager = AssetManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    
    @State private var showSportPicker = false
    @State private var showingCitySelection = false
    @State private var isDragging: Bool = false     // 是否处于拖动中
    
    var body: some View {
        ZStack {
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
                ZStack {
                    HStack {
                        // 运动选择模块
                        HStack(spacing: 4) {
                            Image("sport_selected_side_bar_button")
                                //.renderingMode(.template)     // 告诉系统这是“模板图标”
                                .resizable()
                                .scaledToFit()
                                //.foregroundStyle(Color.orange)
                                .frame(width: 20, height: 20)
                            
                            //Text(appState.sport.name)
                            //    .font(.headline)
                            
                            Image(systemName: appState.sport.iconName)
                                .font(.system(size: 20))
                        }
                        .foregroundStyle(.white)
                        .exclusiveTouchTapGesture {
                            if !isDragging {
                                withAnimation(.easeIn(duration: 0.25)) {
                                    appState.navigationManager.showSideBar = true
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // 定位
                        HStack(spacing: 2) {
                            Image("location")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text(locationManager.region ?? "未知")
                                .foregroundColor(.white)
                        }
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.append(.regionSelectedView)
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    // 居中图案
                    HStack {
                        Text(viewModel.seasonName)
                            .font(.headline)
                            .foregroundStyle(Color.white)
                    }
                }
                .padding(.bottom, 5)
                
                if appState.sport == .Bike {
                    BikeCompetitionView(centerViewModel: viewModel, isDragging: $isDragging)
                } else if appState.sport == .Running {
                    RunningCompetitionView(centerViewModel: viewModel, isDragging: $isDragging)
                }
            }
        }
        .onFirstAppear {
            viewModel.fetchCurrentSeason()
            // 解决第一次安装打开app时定位权限申请早于网络权限申请导致的更新问题
            if let location = LocationManager.shared.getLocation() {
                viewModel.updateCity(from: location)
            }
        }
        .onValueChange(of: appState.sport) {
            viewModel.fetchCurrentSeason()
        }
    }
}

struct TrainingCenterView: View {
    //@StateObject var viewModel: PVPCompetitionViewModel
    
    var body: some View {
        VStack {
            Text("Running比赛页面")
                .font(.largeTitle)
                .fontWeight(.bold)
            // 添加更多的训练页面内容
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct TeamDescriptionView: View {
    @Binding var showDetailSheet: Bool
    @Binding var selectedDescription: String
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundStyle(.clear)
                
                Spacer()
                
                Text("队伍描述")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    showDetailSheet = false
                }) {
                    Text("完成")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondText)
                }
            }
            ScrollView {
                Text(selectedDescription.isEmpty ? "暂无内容" : selectedDescription)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(5)
            }
            .frame(height: 100)
            .padding(10)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(20)
            
            Spacer()
        }
        .padding()
        .background(Color.defaultBackground)
    }
}

// 赛道信息项组件
struct InfoItemView: View {
    let iconName: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 15))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24, alignment: .center)
            
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .foregroundColor(.secondText)
        }
    }
}

// 组队报名页面
struct TeamRegisterView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    
    @State var teamCode: String = ""
    @Binding var showSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    showSheet = false
                }) {
                    Text("取消")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.thirdText)
                }
                
                Spacer()
                
                Text("组队报名")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondText)
                
                Spacer()
                
                Button(action: {
                    registerWithTeamCode()
                }) {
                    Text("报名")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("使用队伍码报名队伍所在比赛")
                    .font(.subheadline)
                    .foregroundColor(.secondText)
                TextField(text: $teamCode) {
                    Text("请输入8位队伍码")
                        .foregroundStyle(Color.thirdText)
                }
                .padding()
                .foregroundColor(.white)
                .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
            Spacer()
        }
        .padding()
        .background(Color.defaultBackground)
        //.hideKeyboardOnScroll()
        .onValueChange(of: showSheet) {
            if showSheet {
                teamCode = ""
            } else {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    // 使用队伍码报名
    func registerWithTeamCode() {
        guard teamCode.count == 8 else {
            let toast = Toast(message: "请输入合法的8位队伍码")
            ToastManager.shared.show(toast: toast)
            return
        }
        guard var components = URLComponents(string: "/competition/\(appState.sport.rawValue)/team_register") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_code", value: teamCode)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        showSheet = false
                        assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                    }
                }
            default: break
            }
        }
    }
}

struct TrackMapView: UIViewRepresentable {
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    let startRadius: CLLocationDistance
    let endRadius: CLLocationDistance
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.delegate = context.coordinator
        mapView.addAnnotations([context.coordinator.fromAnnotation, context.coordinator.toAnnotation])
        
        // 隐藏底部 "Legal" 图标
        for subview in mapView.subviews {
            if String(describing: type(of: subview)).contains("Attribution") {
                subview.isHidden = true
            }
        }
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新坐标
        context.coordinator.fromAnnotation.coordinate = fromCoordinate
        context.coordinator.toAnnotation.coordinate = toCoordinate
        // 添加圆形覆盖层
        uiView.removeOverlays(uiView.overlays)
        let circle1 = MKCircle(center: fromCoordinate, radius: startRadius)
        let circle2 = MKCircle(center: toCoordinate, radius: endRadius)
        uiView.addOverlays([circle1, circle2])
        
        let points: [CLLocationCoordinate2D] = [fromCoordinate, toCoordinate]
        var mapRect = MKMapRect.null
        for point in points {
            let p = MKMapPoint(point)
            mapRect = mapRect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        
        let edgePadding = UIEdgeInsets(top: 50, left: 60, bottom: 50, right: 60)
        uiView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let fromAnnotation = MKPointAnnotation()
        let toAnnotation = MKPointAnnotation()
        
        override init() {
            super.init()
            fromAnnotation.title = "From"
            toAnnotation.title = "To"
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            let identifier = "customMarker"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
                // 设置自定义图标
                if let originalImage = UIImage(systemName: "bicycle") {
                    let size = CGSize(width: 40, height: 30)
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    
                    let tinted = originalImage.withTintColor(.orange, renderingMode: .alwaysOriginal)
                    tinted.draw(in: CGRect(origin: .zero, size: size))
                    
                    let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    view?.image = finalImage
                }
            } else {
                view?.annotation = annotation
            }
            
            return view
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.orange.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.orange.withAlphaComponent(0.6)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// 全屏地图视图
struct FullScreenMapView: View {
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    let startRadius: CLLocationDistance
    let endRadius: CLLocationDistance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FullScreenMapRepresentable(
                fromCoordinate: fromCoordinate,
                toCoordinate: toCoordinate,
                startRadius: startRadius,
                endRadius: endRadius
            )
            .ignoresSafeArea()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding()
        }
        .background(Color.black)
    }
}

struct FullScreenMapRepresentable: UIViewRepresentable {
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    let startRadius: CLLocationDistance
    let endRadius: CLLocationDistance

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.delegate = context.coordinator
        
        context.coordinator.fromAnnotation.coordinate = fromCoordinate
        context.coordinator.toAnnotation.coordinate = toCoordinate
        mapView.addAnnotations([context.coordinator.fromAnnotation, context.coordinator.toAnnotation])
        
        // 添加圆形覆盖层
        let circle1 = MKCircle(center: fromCoordinate, radius: startRadius)
        let circle2 = MKCircle(center: toCoordinate, radius: endRadius)
        mapView.addOverlays([circle1, circle2])
        
        // 隐藏底部 "Legal" 图标
        for subview in mapView.subviews {
            if String(describing: type(of: subview)).contains("Attribution") {
                subview.isHidden = true
            }
        }
        
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let points: [CLLocationCoordinate2D] = [fromCoordinate, toCoordinate]
        var mapRect = MKMapRect.null
        for point in points {
            let p = MKMapPoint(point)
            mapRect = mapRect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        
        let edgePadding = UIEdgeInsets(top: 180, left: 60, bottom: 180, right: 60)
        uiView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let fromAnnotation = MKPointAnnotation()
        let toAnnotation = MKPointAnnotation()
        override init() {
            fromAnnotation.title = "From"
            toAnnotation.title = "To"
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.orange.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.orange.withAlphaComponent(0.6)
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#Preview {
    let appState = AppState.shared
    return SportCenterView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}
