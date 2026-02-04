//
//  SportCenterView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/5.
//

import SwiftUI
import MapKit


struct SportCenterView: View {
    @ObservedObject var viewModel: CompetitionCenterViewModel
    
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
                            
                            Image(appState.sport.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)
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
                            Text(locationManager.regionName ?? "error.unknown")
                                .foregroundColor(.white)
                        }
                        .exclusiveTouchTapGesture {
                            appState.navigationManager.append(.regionSelectedView)
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    // 居中图案
                    HStack(spacing: 4) {
                        if let season = viewModel.seasonInfo {
                            Text(season.name)
                                .font(.headline)
                                .foregroundStyle(Color.white)
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondText)
                                .exclusiveTouchTapGesture {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "competition.season.info",
                                        bottomButtons: [
                                            .confirm()
                                        ]
                                    ) {
                                        VStack {
                                            Text("competition.begin_date") + Text(LocalizedStringKey(DateDisplay.formattedDate(season.startDate)))
                                            Text("competition.end_date") + Text(LocalizedStringKey(DateDisplay.formattedDate(season.endDate)))
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(Color.secondText)
                                    }
                                }
                        } else {
                            Text("error.unknown")
                                .font(.headline)
                                .foregroundStyle(Color.thirdText)
                        }
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
            if let location = locationManager.getLocation(), locationManager.regionID == nil {
                viewModel.updateCity(from: location)
            }
            PopupWindowManager.shared.presentPopup(
                title: "user.setup.realname_auth.undone",
                message: "user.setup.realname_auth.popup.no_auth",
                doNotShowAgainKey: "sportCenterView.realname",
                bottomButtons: [
                    .cancel("login.reigster.popup.action.cancel"),
                    .confirm("user.intro.go_auth") {
                        appState.navigationManager.append(.realNameAuthView)
                    }
                ]
            )
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
                Text("action.cancel")
                    .font(.system(size: 16))
                    .foregroundStyle(.clear)
                
                Spacer()
                
                Text("competition.team.intro")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    showDetailSheet = false
                }) {
                    Text("action.complete")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondText)
                }
            }
            ScrollView {
                if selectedDescription.isEmpty {
                    Text("competition.team.description.no_content")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(5)
                } else {
                    Text(selectedDescription)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(5)
                }
            }
            //.frame(height: 100)
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
    let text: String
    let param: String
    let unit: String?
    let isSysIcon: Bool
    
    init(iconName: String, text: String, param: String, unit: String? = nil, isSysIcon: Bool = false) {
        self.iconName = iconName
        self.text = text
        self.param = param
        self.unit = unit
        self.isSysIcon = isSysIcon
    }
    
    var body: some View {
        HStack(spacing: 5) {
            if isSysIcon {
                Image(systemName: iconName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white)
            } else {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
            }
            HStack(spacing: 2) {
                if let unit = unit {
                    (Text(LocalizedStringKey(text)) + Text(": ") + Text(LocalizedStringKey(param)) + Text(LocalizedStringKey(unit)))
                } else {
                    (Text(LocalizedStringKey(text)) + Text(": ") + Text(LocalizedStringKey(param)))
                }
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .foregroundStyle(Color.secondText)
        }
    }
}

// 组队报名页面
struct TeamRegisterView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    
    @State var teamCode: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("competition.register.team.content")
                .font(.subheadline)
                .foregroundColor(.secondText)
                .multilineTextAlignment(.center)
            TextField(text: $teamCode) {
                Text("competition.register.team.placeholder")
                    .foregroundStyle(Color.thirdText)
            }
            .padding()
            .foregroundColor(.white)
            .scrollContentBackground(.hidden) // 隐藏系统默认的背景
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            //Spacer()
            HStack {
                Button {
                    registerWithTeamCode()
                } label: {
                    Text("competition.register.team.2")
                        .foregroundStyle(teamCode.count == 8 ? Color.white : Color.thirdText)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(teamCode.count == 8 ? Color.orange : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(teamCode.count != 8)
            }
        }
    }
    
    // 使用队伍码报名
    func registerWithTeamCode() {
        guard teamCode.count == 8 else { return }
        guard var components = URLComponents(string: "/competition/\(appState.sport.rawValue)/team_register") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_code", value: teamCode)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        PopupWindowManager.shared.dismissPopup()
                        assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                        ToastManager.shared.show(toast: Toast(message: "competition.register.result.success"))
                    }
                }
            default: break
            }
        }
    }
}

enum TrackPointType {
    case start
    case end
}

final class TrackPointAnnotation: MKPointAnnotation {
    let type: TrackPointType

    init(type: TrackPointType) {
        self.type = type
        super.init()
    }
}

final class TrackPointAnnotationView: MKAnnotationView {
    private let titleLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }

    private func setupUI() {
        canShowCallout = false

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        titleLabel.layer.cornerRadius = 4
        titleLabel.clipsToBounds = true

        addSubview(titleLabel)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        guard let image = image else { return }

        bounds = CGRect(origin: .zero, size: image.size)

        titleLabel.sizeToFit()
        titleLabel.frame = CGRect(
            x: -(titleLabel.bounds.width - image.size.width) / 2 - 10,
            y: image.size.height + 2,
            width: titleLabel.bounds.width + 20,
            height: titleLabel.bounds.height + 10
        )

        centerOffset = CGPoint(x: 0, y: -image.size.height / 2)
    }

    func configure(title: String) {
        titleLabel.text = title
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
        
        let edgePadding = UIEdgeInsets(top: 60, left: 60, bottom: 40, right: 60)
        //DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        uiView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
        //}
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let fromAnnotation = TrackPointAnnotation(type: .start)
        let toAnnotation = TrackPointAnnotation(type: .end)

        override init() {
            super.init()
            fromAnnotation.title = "From"
            toAnnotation.title = "To"
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? TrackPointAnnotation else { return nil }
            
            let identifier = "TrackPointAnnotationView"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            as? TrackPointAnnotationView
            ?? TrackPointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            let imageName: String
            let titleText: String
            
            switch annotation.type {
            case .start:
                imageName = "flag_start"
                titleText = NSLocalizedString("competition.track.start", comment: "")
            case .end:
                imageName = "flag_finish"
                titleText = NSLocalizedString("competition.track.finish", comment: "")
            }
            
            view.image = UIImage(named: imageName)
            view.configure(title: titleText)
            
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
        
        let edgePadding = UIEdgeInsets(top: 180, left: 60, bottom: 180, right: 60)
        uiView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let fromAnnotation = TrackPointAnnotation(type: .start)
        let toAnnotation = TrackPointAnnotation(type: .end)
        
        override init() {
            fromAnnotation.title = "From"
            toAnnotation.title = "To"
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? TrackPointAnnotation else { return nil }
            
            let identifier = "TrackPointAnnotationView.Fullscreen"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            as? TrackPointAnnotationView
            ?? TrackPointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            let imageName: String
            let titleText: String
            
            switch annotation.type {
            case .start:
                imageName = "flag_start"
                titleText = NSLocalizedString("competition.track.start", comment: "")
            case .end:
                imageName = "flag_finish"
                titleText = NSLocalizedString("competition.track.finish", comment: "")
            }
            
            view.image = UIImage(named: imageName)
            view.configure(title: titleText)
            
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

/*#Preview {
    let appState = AppState.shared
    return SportCenterView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}*/
