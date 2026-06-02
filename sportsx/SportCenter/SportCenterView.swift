//
//  SportCenterView.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/5.
//

import SwiftUI
import MapKit


/*struct SportCenterView: View {
    @ObservedObject var viewModel: CompetitionCenterViewModel
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            CompetitionCenterView(viewModel: viewModel)
        }
    }
}*/

struct SportCenterView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: CompetitionCenterViewModel
    @ObservedObject var assetManager = AssetManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    
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
                            
                            Image(appState.sport.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)
                            Text(appState.sportFeature.title)
                                .font(.system(size: 18, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: 150, alignment: .leading)
                        .foregroundStyle(Color.white)
                        .exclusiveTouchTapGesture {
                            if !isDragging {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    appState.navigationManager.showSideBar = true
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // 定位
                        //if appState.sportFeature == .bikeRace || appState.sportFeature == .runningRace {
                            HStack(spacing: 2) {
                                Image("location")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text(locationManager.regionName ?? "error.unknown")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: 150, alignment: .trailing)
                            .exclusiveTouchTapGesture {
                                appState.navigationManager.append(.regionSelectedView)
                            }
                        //}
                    }
                    .padding(.horizontal, 10)
                    .foregroundStyle(Color.white)
                    
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
                                            Text("competition.begin_date") + Text("：") + Text(LocalizedStringKey(DateDisplay.formattedDate(season.startDate)))
                                            Text("competition.end_date") + Text("：") + Text(LocalizedStringKey(DateDisplay.formattedDate(season.endDate)))
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
                
                Rectangle()
                    .foregroundStyle(Color.gray)
                    .frame(height: 1)
                
                switch appState.sportFeature {
                case .bikeRace:
                    BikeCompetitionView(centerViewModel: viewModel, isDragging: $isDragging)
                case .bikeFreeTraining:
                    BikeFreeTrainingView()
                case .bikeRouteTraining:
                    BikeRouteTrainingView()
                case .runningRace:
                    RunningCompetitionView(centerViewModel: viewModel, isDragging: $isDragging)
                case .runningFreeTraining:
                    RunningFreeTrainingView()
                case .runningRouteTraining:
                    RunningRouteTrainingView()
                }
            }
        }
        .onFirstAppear {
            viewModel.fetchCurrentSeason()
            // 解决第一次安装打开app时定位权限申请早于网络权限申请导致的更新问题
            if let location = locationManager.getLocation(), locationManager.regionID == nil {
                viewModel.updateCity(from: location)
            }
        }
        .onValueChange(of: appState.sport) { _, _ in
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
                Image(systemName: "xmark")
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

struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool

    var body: some View {
        ZStack {
            // 背景
            Circle()
                .fill(isSelected ? Color.orange.opacity(0.5) : day.backgroundColor)
            
            // 圆环
            Circle()
                .trim(from: day.delta >= 0 ? 0 : 1 - progress,
                      to: day.delta >= 0 ? progress : 1)
                .stroke(day.foregroundColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                //.animation(.easeInOut(duration: 3), value: day.delta)
            
            // 日期
            Text("\(day.dayNumber)")
                .font(.subheadline)
                .foregroundStyle(isSelected ? Color.clear : Color.secondText)
            
            // 选中时显示 delta 数值
            if isSelected {
                Text(day.deltaText)
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(day.foregroundColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
        }
        // 不再写死宽高：由 LazyVGrid 的弹性列决定宽度，保持 1:1 方形，
        // 小屏（如 7 列下单列宽 < 50）也能自适应缩放而不溢出
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var progress: CGFloat {
        let maxValue: CGFloat = 20      // 每日上限为 20
        let value = min(abs(CGFloat(day.delta)) / maxValue, 1.0)
        return value
    }
}

struct CalendarHeaderView: View {
    var monthText: String
    var onPrev: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .padding(10)
                    .background(Color.gray.opacity(0.5))
                    .clipShape(Circle())
            }
            Spacer()
            Text(monthText)
                .font(.headline)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .padding(10)
                    .background(Color.gray.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
        .foregroundStyle(Color.white)
    }
}

struct RegionMapView: UIViewRepresentable {
    let polygons: [MKPolygon]
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        map.delegate = context.coordinator
        return map
    }
    
    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.addOverlays(polygons)
        
        var rect = MKMapRect.null
        for polygon in polygons {
            rect = rect.union(polygon.boundingMapRect)
        }
        if !rect.isNull {
            map.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                animated: true
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
        ) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = .systemOrange
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

class TileOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect
    var coords: [CLLocationCoordinate2D]
    var counts: [Int]
    var level: Int
    
    init(coordinates: [CLLocationCoordinate2D], counts: [Int], level: Int) {
        self.coords = coordinates
        self.counts = counts
        self.level = level
        
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        self.coordinate = polygon.coordinate
        self.boundingMapRect = polygon.boundingMapRect
    }
}

class TileRenderer: MKOverlayRenderer {
    let tile: TileOverlay

    init(overlay: TileOverlay) {
        self.tile = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let coords = tile.coords
        let counts = tile.counts

        var index = 0
        var i = 0

        while i + 3 < coords.count {
            let c0 = coords[i]
            let c1 = coords[i + 1]
            let c2 = coords[i + 2]
            let c3 = coords[i + 3]

            let p0 = self.point(for: MKMapPoint(c0))
            let p1 = self.point(for: MKMapPoint(c1))
            let p2 = self.point(for: MKMapPoint(c2))
            let p3 = self.point(for: MKMapPoint(c3))

            let minX = min(min(p0.x, p1.x), min(p2.x, p3.x))
            let maxX = max(max(p0.x, p1.x), max(p2.x, p3.x))
            let minY = min(min(p0.y, p1.y), min(p2.y, p3.y))
            let maxY = max(max(p0.y, p1.y), max(p2.y, p3.y))

            let rect = CGRect(
                x: minX,
                y: minY,
                width: maxX - minX,
                height: maxY - minY
            )

            let count = index < counts.count ? counts[index] : 0

            let color: UIColor
            let borderColor: UIColor
            if count > 0 {
                let alpha = min(0.1 + Double(count) * 0.05, 0.6)
                color = UIColor.orange.withAlphaComponent(alpha)
                borderColor = UIColor.orange
            } else {
                color = UIColor.gray.withAlphaComponent(0.3)
                borderColor = UIColor.black.withAlphaComponent(0.2)
            }

            context.setFillColor(color.cgColor)
            context.fill(rect)
            
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(0.5 / zoomScale)
            context.stroke(rect)

            index += 1
            i += 4
        }
    }
}

class SelectedGridOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect
    var polygon: MKPolygon

    init(polygon: MKPolygon) {
        self.polygon = polygon
        self.coordinate = polygon.coordinate
        self.boundingMapRect = polygon.boundingMapRect
    }
}


class RoutePointAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let size: Int
    let type: EditableCheckPointType
    let penalty: Int?
    
    init(coordinate: CLLocationCoordinate2D, size: Int, type: EditableCheckPointType, penalty: Int? = nil) {
        self.coordinate = coordinate
        self.size = size
        self.type = type
        self.penalty = penalty
    }
}

class RoutePointAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet {
            guard let ann = annotation as? RoutePointAnnotation else { return }
            setup(for: ann)
        }
    }
    
    private func setup(for ann: RoutePointAnnotation) {
        self.subviews.forEach { $0.removeFromSuperview() }

        let size: CGFloat = CGFloat(ann.size)
        let spacing: CGFloat = ann.penalty != nil ? 4 : 0
        var penaltyHeight: CGFloat = 0

        switch ann.type {
        case .start:
            let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circle.backgroundColor = .systemGreen
            circle.layer.cornerRadius = size / 2
            circle.layer.borderColor = UIColor.white.cgColor
            circle.layer.borderWidth = 2
            self.addSubview(circle)

        case .end:
            let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circle.backgroundColor = .systemRed
            circle.layer.cornerRadius = size / 2
            circle.layer.borderColor = UIColor.white.cgColor
            circle.layer.borderWidth = 2
            self.addSubview(circle)

        case .checkPoint(let index):
            let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circle.backgroundColor = .orange
            circle.layer.cornerRadius = size / 2
            circle.layer.borderColor = UIColor.white.cgColor
            circle.layer.borderWidth = 2
            self.addSubview(circle)

            let label = UILabel(frame: CGRect(x: 0, y: 0, width: size, height: size))
            label.text = "\(index)"
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            label.textColor = .white
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5

            self.addSubview(label)

            if let penalty = ann.penalty {
                let penaltyLabel = UILabel()
                penaltyLabel.text = "+\(penalty)s"
                penaltyLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
                penaltyLabel.textColor = .white
                penaltyLabel.textAlignment = .center
                penaltyLabel.backgroundColor = penalty > 0 ? UIColor.systemPink : UIColor.systemGreen
                penaltyLabel.layer.cornerRadius = 4
                penaltyLabel.layer.masksToBounds = true

                penaltyLabel.sizeToFit()

                let paddingX: CGFloat = 6
                let paddingY: CGFloat = 2
                let width = penaltyLabel.frame.width + paddingX * 2
                let height = penaltyLabel.frame.height + paddingY * 2
                penaltyHeight = height

                penaltyLabel.frame = CGRect(
                    x: (size - width) / 2,
                    y: size + spacing,
                    width: width,
                    height: height
                )

                self.addSubview(penaltyLabel)
            }
        }
        let totalHeight = size + spacing + penaltyHeight
        self.frame = CGRect(x: 0, y: 0, width: size, height: totalHeight)
        let offsetY = (penaltyHeight + spacing) / 2
        self.centerOffset = CGPoint(x: 0, y: offsetY)
    }
}

struct FullScreenRouteMapView: View {
    @Binding var showMap: Bool
    let routePoints: [RoutePoint]
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            FullScreenRouteMapRepresentable(routePoints: routePoints)
                .ignoresSafeArea()
            
            Button(action: { showMap = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
}

struct FullScreenRouteMapRepresentable: UIViewRepresentable {
    let routePoints: [RoutePoint]
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = false
        map.delegate = context.coordinator
        
        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        config.pointOfInterestFilter = .excludingAll
        config.emphasisStyle = .muted
        map.preferredConfiguration = config
        
        map.register(RoutePointAnnotationView.self, forAnnotationViewWithReuseIdentifier: "routePoint")
        map.pointOfInterestFilter = .excludingAll
        
        var coords: [CLLocationCoordinate2D] = []
        for point in routePoints {
            switch point {
            case .checkpoint(let cp):
                coords.append(CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng)))
            default:
                continue
            }
        }
        if coords.count > 1 {
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            let rect = polyline.boundingMapRect
            let padding = UIEdgeInsets(top: 80, left: 80, bottom: 80, right: 80)
            map.setVisibleMapRect(rect, edgePadding: padding, animated: false)
        }
        
        return map
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        var coords: [CLLocationCoordinate2D] = []
        for point in routePoints {
            switch point {
            case .checkpoint(let cp):
                let parseCoord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng))
                coords.append(parseCoord)
                let checkCircle = MKCircle(center: parseCoord, radius: cp.radius)
                mapView.addOverlay(checkCircle)
            default:
                continue
            }
        }
        
        if coords.count > 1 {
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            mapView.addOverlay(polyline)
        }

        for (index, point) in routePoints.enumerated() {
            if case .checkpoint(let cp) = point {
                let coord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng))
                
                let type: EditableCheckPointType
                if index == 0 {
                    type = .start
                } else if index == routePoints.count - 1 {
                    type = .end
                } else {
                    type = .checkPoint(index)
                }
                
                let ann = RoutePointAnnotation(coordinate: coord, size: 24, type: type, penalty: cp.penalty)
                mapView.addAnnotation(ann)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemOrange
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.lineDashPattern = [3, 5]   // 虚线：5pt 实线 + 5pt 间隔
                return renderer
            }
            
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.orange.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.orange.withAlphaComponent(0.6)
                renderer.lineWidth = 2
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "routePoint"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? RoutePointAnnotationView

            if view == nil {
                view = RoutePointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }
            view?.canShowCallout = false
            return view
        }
    }
}

struct MapPreviewRepresentable: UIViewRepresentable {
    var routePoints: [RoutePoint]
    let polygons: [MKPolygon]
    let needParse: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        map.delegate = context.coordinator
        
        let config = MKStandardMapConfiguration(elevationStyle: .flat)
        config.pointOfInterestFilter = .excludingAll
        config.emphasisStyle = .muted

        map.preferredConfiguration = config
        map.showsBuildings = false
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        var coords: [CLLocationCoordinate2D] = []
        
        for point in routePoints {
            switch point {
            case .checkpoint(let cp):
                let coord = needParse ? CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng)) : CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng)
                coords.append(coord)
            default:
                continue
            }
        }
        
        // 如果没有路线点，展示 region boundary
        if coords.isEmpty {
            if !polygons.isEmpty {
                mapView.addOverlays(polygons)
                
                // 计算所有 polygon 的 bounding rect
                let unionRect = polygons
                    .map { $0.boundingMapRect }
                    .reduce(MKMapRect.null) { $0.union($1) }
                
                let padding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
                mapView.setVisibleMapRect(unionRect, edgePadding: padding, animated: false)
            }
            return
        }

        if coords.count > 1 {
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            mapView.addOverlay(polyline)

            let rect = polyline.boundingMapRect
            let padding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
        } else {
            let region = MKCoordinateRegion(center: coords[0], latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: false)
        }
        
        if let first = coords.first {
            let ann = RoutePointAnnotation(coordinate: first, size: 16, type: .start)
            mapView.addAnnotation(ann)
        }

        if let last = coords.last, coords.count > 1 {
            let ann = RoutePointAnnotation(coordinate: last, size: 16, type: .end)
            mapView.addAnnotation(ann)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemOrange
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.lineDashPattern = [2, 4]   // 虚线：5pt 实线 + 5pt 间隔
                return renderer
            }
            
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.8)
                renderer.lineWidth = 2
                renderer.fillColor = UIColor.clear
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "routePoint"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? RoutePointAnnotationView

            if view == nil {
                view = RoutePointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                view?.annotation = annotation
            }
            view?.canShowCallout = false
            return view
        }
    }
}

struct MapContainerView: UIViewRepresentable {
    @ObservedObject var camera: MapCameraState
    @ObservedObject var store: RouteEditorStore
    let polygons: [MKPolygon]
    @Binding var selectedPointID: UUID?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.addOverlays(polygons)
        camera.mapView = map
        
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.3
        longPress.delegate = context.coordinator
        longPress.cancelsTouchesInView = false

        map.addGestureRecognizer(longPress)
        
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator

        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        camera.mapView = mapView
        
        // 初次进入时自动聚焦到路径
        if !context.coordinator.hasSetInitialRegion {
            if !store.tempRoutePoints.isEmpty {
                let coords = store.tempRoutePoints.map { $0.coordinate }
                
                if coords.count > 1 {
                    let polyline = MKPolyline(coordinates: coords, count: coords.count)
                    let rect = polyline.boundingMapRect
                    let padding = UIEdgeInsets(top: 80, left: 80, bottom: 80, right: 80)
                    mapView.setVisibleMapRect(rect, edgePadding: padding, animated: false)
                } else if let first = coords.first {
                    let region = MKCoordinateRegion(center: first, latitudinalMeters: 500, longitudinalMeters: 500)
                    mapView.setRegion(region, animated: false)
                }
            } else if !polygons.isEmpty {
                let unionRect = polygons
                    .map { $0.boundingMapRect }
                    .reduce(MKMapRect.null) { $0.union($1) }
                
                let padding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
                mapView.setVisibleMapRect(unionRect, edgePadding: padding, animated: false)
            }
            DispatchQueue.main.async {
                context.coordinator.hasSetInitialRegion = true
                context.coordinator.mapViewDidChangeVisibleRegion(mapView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, camera: camera)
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let camera: MapCameraState
        var parent: MapContainerView
        var draggingID: UUID?
        var hasSetInitialRegion = false

        init(_ parent: MapContainerView, camera: MapCameraState) {
            self.parent = parent
            self.camera = camera
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            guard hasSetInitialRegion else { return }
            
            if #available(iOS 26.0, *) {
                DispatchQueue.main.async {
                    self.camera.update(from: mapView)
                }
            } else {
                camera.update(from: mapView)
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        private func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBegin otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)

            if let hit = findHitPoint(at: point, in: mapView) {
                parent.selectedPointID = hit.id
            } else {
                parent.selectedPointID = nil
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            
            switch gesture.state {
            case .began:
                mapView.isScrollEnabled = false
                mapView.isZoomEnabled = false
                mapView.isRotateEnabled = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if let hit = findHitPoint(at: point, in: mapView) {
                    draggingID = hit.id
                } else {
                    if parent.store.tempSelectedType == .pointToPoint, parent.store.tempRoutePoints.count > 1 {
                        UINotificationFeedbackGenerator()
                            .notificationOccurred(.warning)
                        ToastManager.shared.show(
                            toast: Toast(
                                message: "training.route.create.toast.over_points %lld",
                                args: [2]
                            )
                        )
                        return
                    }
                    // 当路径点数量达到限制后禁止再添加
                    let maxPointCount = UserManager.shared.user.isVip == true ? 100 : 10
                    guard parent.store.tempRoutePoints.count < maxPointCount else {
                        UINotificationFeedbackGenerator()
                            .notificationOccurred(.warning)
                        ToastManager.shared.show(
                            toast: Toast(
                                message: "training.route.create.toast.over_points %lld",
                                args: [maxPointCount]
                            )
                        )
                        return
                    }
                    let isInside = parent.store.isCoordinate(coord, inside: parent.polygons)
                    parent.store.tempRoutePoints.append(
                        EditableRoutePoint(coordinate: coord, type: .end, isOutOfBounds: !isInside)
                    )
                    updateTypes()
                }
                return
            case .changed:
                if let id = draggingID, let index = parent.store.tempRoutePoints.firstIndex(where: { $0.id == id }) {
                    parent.store.tempRoutePoints[index].coordinate = coord
                    
                    let isInside = parent.store.isCoordinate(coord, inside: parent.polygons)
                    parent.store.tempRoutePoints[index].isOutOfBounds = !isInside
                }
            case .ended, .cancelled:
                draggingID = nil
                mapView.isScrollEnabled = true
                mapView.isZoomEnabled = true
                mapView.isRotateEnabled = true
            default:
                break
            }
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.6)
                renderer.lineWidth = 2
                renderer.fillColor = UIColor.clear
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func findHitPoint(at point: CGPoint, in mapView: MKMapView) -> EditableRoutePoint? {
            return parent.store.tempRoutePoints.first { p in
                let screen = mapView.convert(p.coordinate, toPointTo: mapView)
                return hypot(screen.x - point.x, screen.y - point.y) < 30
            }
        }
        
        func updateTypes() {
            for i in parent.store.tempRoutePoints.indices {
                if i == 0 {
                    parent.store.tempRoutePoints[i].type = .start
                } else if i == parent.store.tempRoutePoints.count - 1 {
                    parent.store.tempRoutePoints[i].type = .end
                } else {
                    if parent.store.tempRoutePoints[i].penalty == nil {
                        parent.store.tempRoutePoints[i].penalty = 30
                    }
                    parent.store.tempRoutePoints[i].type = .checkPoint(i)
                }
            }
        }
    }
}



struct RouteEditorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: RouteEditorStore
    @StateObject var camera = MapCameraState()
    @ObservedObject var userManager = UserManager.shared
    
    @State private var selectedPointID: UUID? = nil
    
    @State private var tempRadius: Double = 20
    
    var body: some View {
        ZStack {
            // Map（只负责 camera）
            MapContainerView(camera: camera, store: store, polygons: LocationManager.shared.regionBoundary, selectedPointID: $selectedPointID)
                .ignoresSafeArea()
            
            // SwiftUI Overlay
            RouteOverlayView(
                camera: camera,
                store: store,
                selectedPointID: $selectedPointID
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // SwiftUI 工具栏
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Button(action: {
                        appState.navigationManager.removeLast()
                    }) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.medium)
                            .frame(width: 20, height: 20)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Picker("", selection: $store.tempSelectedType) {
                        ForEach(RouteType.allCases, id: \.self) {
                            Text(LocalizedStringKey($0.displayName))
                                .fontWeight(.medium)
                        }
                    }
                    .pickerStyle(.segmented)
                    //.frame(width: 150)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule()
                            .foregroundStyle(Color.defaultBackground)
                    )
                    Spacer()
                    Button(action: {
                        if let error = store.saveValidPath() {
                            let message: String
                            switch error {
                            case .notEnoughPoints:
                                message = "training.route.create.toast.save_error.1"
                            case .invalidStructure:
                                message = "training.route.create.toast.save_error.2"
                            case .radiusOverlap:
                                message = "training.route.create.toast.save_error.3"
                            case .outOfBounds:
                                message = "training.route.create.toast.save_error.4"
                            }
                            ToastManager.shared.show(toast: Toast(message: message))
                            return
                        }
                        store.fetchElevation()
                        appState.navigationManager.removeLast()
                    }) {
                        Image(systemName: "checkmark")
                            .fontWeight(.medium)
                            .frame(width: 20, height: 20)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal)
                
                if store.tempSelectedType == .multiPoints {
                    let maxPointCount = userManager.user.isVip == true ? 100 : 10
                    let remainingCount = max(0, maxPointCount - store.tempRoutePoints.count)
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.black.opacity(0.6), lineWidth: 6)
                                .frame(width: 45, height: 45)
                            Circle()
                                .trim(
                                    from: 0,
                                    to: CGFloat(
                                        min(
                                            Double(store.tempRoutePoints.count) / Double(maxPointCount),
                                            1.0
                                        )
                                    )
                                )
                                .stroke(
                                    remainingCount <= 3 ? Color.pink : Color.orange,
                                    style: StrokeStyle(
                                        lineWidth: 6,
                                        lineCap: .round
                                    )
                                )
                                .frame(width: 45, height: 45)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text("\(remainingCount)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                                Text("common.left")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.secondText)
                            }
                        }
                        if !userManager.user.isVip {
                            HStack(spacing: 4) {
                                Text("training.route.create.unlock_points")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.secondText)
                                Image("vip_icon_on")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 15)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .exclusiveTouchTapGesture {
                                guard userManager.isLoggedIn else {
                                    userManager.showingLogin = true
                                    return
                                }
                                appState.navigationManager.append(.subscriptionDetailView)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
                
                if let index = store.tempRoutePoints.firstIndex(where: { $0.id == selectedPointID }) {
                    VStack(spacing: 10) {
                        Text("training.route.create.pathpoint")
                            .font(.system(size: 15, weight: .bold))

                        HStack(spacing: 20) {
                            (Text("common.radius") + Text(": ") + Text("\(Int(store.tempRoutePoints[index].radius)) m"))
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 100, alignment: .leading)

                            Slider(
                                value: $tempRadius,
                                in: 10...100
                            )
                            .frame(width: 200)
                        }

                        if let penalty = store.tempRoutePoints[index].penalty {
                            HStack(spacing: 20) {
                                (Text("training.route.create.penalty_time") + Text(": ") + Text("\(penalty) s"))
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 150, alignment: .leading)
                                Stepper(
                                    "", value: Binding(
                                        get: { store.tempRoutePoints[index].penalty ?? 0 },
                                        set: { store.tempRoutePoints[index].penalty = $0 }
                                    ),
                                    in: 0...60,
                                    step: 10
                                )
                                .frame(width: 150)
                            }
                        }
                    }
                    .padding(10)
                    .foregroundColor(.white)
                    .background(Color.defaultBackground)
                    .cornerRadius(12)
                    .padding(.bottom, 20)
                }
                
                HStack(spacing: 20) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                        )
                    if store.tempSelectedType == .multiPoints {
                        Text("->")
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color.orange, lineWidth: 2)
                            )
                            .overlay(
                                Text("1")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.orange)
                            )
                        Text("->")
                        Image(systemName: "ellipsis")
                        Text("->")
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(Color.orange, lineWidth: 2)
                            )
                            .overlay(
                                Text("n")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.orange)
                            )
                    }
                    Text("->")
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                        )
                }
                .foregroundStyle(Color.secondText)
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .background(Color.defaultBackground)
                
                ZStack {
                    ReorderableListView(items: $store.tempRoutePoints, selectedPointID: $selectedPointID)
                    if store.tempRoutePoints.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.secondText)
                            
                            Text("training.route.create.placeholder")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.thirdText)
                        }
                    }
                }
                .frame(height: 120)
                .background(Color.defaultBackground)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture(false)
        .onStableAppear {
            PopupWindowManager.shared.presentPopup(
                title: "popup.tips",
                message: "training.route.create.popup.tips",
                doNotShowAgainKey: "RouteEditorView.tips",
                bottomButtons: [.confirm()]
            )
        }
        .onValueChange(of: store.tempSelectedType) { _, _ in
            store.tempRoutePoints = []
            selectedPointID = nil
        }
        .onValueChange(of: selectedPointID) { _, _ in
            if let index = store.tempRoutePoints.firstIndex(where: { $0.id == selectedPointID }) {
                tempRadius = store.tempRoutePoints[index].radius
            }
        }
        .onValueChange(of: tempRadius) { _, newValue in
            DispatchQueue.main.async {
                if let index = store.tempRoutePoints.firstIndex(where: { $0.id == selectedPointID }) {
                    store.tempRoutePoints[index].radius = newValue
                }
            }
        }
    }
}

struct ReorderableListView: UIViewRepresentable {
    @Binding var items: [EditableRoutePoint]
    @Binding var selectedPointID: UUID?

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceHorizontal = true

        cv.dataSource = context.coordinator
        cv.delegate = context.coordinator

        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress)
        )

        cv.addGestureRecognizer(longPress)

        // 记得存引用
        context.coordinator.collectionView = cv
        
        return cv
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        guard context.coordinator.draggingCell == nil else { return }
        uiView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject,
        UICollectionViewDataSource,
        UICollectionViewDelegate,
        UICollectionViewDelegateFlowLayout {

        var parent: ReorderableListView
        weak var collectionView: UICollectionView?
        var draggingCell: UICollectionViewCell?

        init(_ parent: ReorderableListView) {
            self.parent = parent
        }

        // MARK: DataSource
        func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.items.count
        }

        func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
            let item = parent.items[indexPath.item]

            var config = UIHostingConfiguration {
                EditableRoutePointView(
                    point: item,
                    isSelected: self.parent.selectedPointID == item.id,
                    onTap: {
                        self.parent.selectedPointID = item.id
                        //self.collectionView?.reloadData()
                    },
                    onDelete: {
                        if let index = self.parent.items.firstIndex(where: { $0.id == item.id }),
                           let cell = self.collectionView?.cellForItem(at: IndexPath(item: index, section: 0)) {
                            UIView.animate(withDuration: 0.25, animations: {
                                cell.alpha = 0
                                cell.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                            }) { _ in
                                if self.parent.selectedPointID == item.id {
                                    self.parent.selectedPointID = nil
                                }
                                self.parent.items.remove(at: index)
                                self.collectionView?.performBatchUpdates {
                                    self.collectionView?.deleteItems(at: [IndexPath(item: index, section: 0)])
                                }
                            }
                        }
                    }
                )
            }
            config = config.margins(.all, 0)
            cell.contentConfiguration = config
            return cell
        }

        // 允许移动
        func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
            return true
        }

        // 数据同步
        func collectionView(_ collectionView: UICollectionView,
                            moveItemAt sourceIndexPath: IndexPath,
                            to destinationIndexPath: IndexPath) {
            let item = parent.items.remove(at: sourceIndexPath.item)
            parent.items.insert(item, at: destinationIndexPath.item)
        }

        // 手势处理
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let collectionView = collectionView else { return }

            let location = gesture.location(in: collectionView)

            switch gesture.state {
            case .began:
                if let indexPath = collectionView.indexPathForItem(at: location),
                   let cell = collectionView.cellForItem(at: indexPath) {
                    draggingCell = cell
                    collectionView.beginInteractiveMovementForItem(at: indexPath)
                    UIView.animate(withDuration: 0.2) {
                        cell.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                        cell.layer.shadowColor = UIColor.black.cgColor
                        cell.layer.shadowOpacity = 0.25
                        cell.layer.shadowRadius = 10
                        cell.layer.shadowOffset = CGSize(width: 0, height: 5)
                        cell.layer.masksToBounds = false
                    }
                }

            case .changed:
                // 只允许横向移动，锁定 y 轴
                if let indexPath = collectionView.indexPathForItem(at: location),
                   let cell = collectionView.cellForItem(at: indexPath) {
                    let centerY = cell.center.y
                    let constrainedPoint = CGPoint(x: location.x, y: centerY)
                    collectionView.updateInteractiveMovementTargetPosition(constrainedPoint)
                } else {
                    // fallback（避免拿不到 cell 时卡住）
                    let constrainedPoint = CGPoint(x: location.x, y: collectionView.bounds.midY)
                    collectionView.updateInteractiveMovementTargetPosition(constrainedPoint)
                }
                // 关键：每一帧都强制保持拖拽态样式（防止交换时被系统重置）
                if let cell = draggingCell {
                    cell.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                    cell.layer.shadowOpacity = 0.25
                    cell.layer.shadowRadius = 10
                }


            case .ended:
                if let cell = draggingCell {
                    UIView.animate(withDuration: 0.2) {
                        cell.transform = .identity
                        cell.layer.shadowOpacity = 0
                        cell.layer.shadowRadius = 0
                    }
                    cell.layer.shadowColor = nil
                }
                draggingCell = nil
                collectionView.endInteractiveMovement()

            default:
                if let cell = draggingCell {
                    UIView.animate(withDuration: 0.2) {
                        cell.transform = .identity
                        cell.layer.shadowOpacity = 0
                        cell.layer.shadowRadius = 0
                    }
                    cell.layer.shadowColor = nil
                }
                draggingCell = nil
                collectionView.cancelInteractiveMovement()
            }
        }

        func collectionView(_ collectionView: UICollectionView,
                            layout collectionViewLayout: UICollectionViewLayout,
                            sizeForItemAt indexPath: IndexPath) -> CGSize {
            let side: CGFloat = 70
            return CGSize(width: side, height: side)
        }
    }
}

struct RoutePointView: View {
    let point: EditableRoutePoint
    
    var body: some View {
        ZStack {
            switch point.type {
            case .start:
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
            case .end:
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
            case .checkPoint(let index):
                Circle()
                    .fill(Color.orange)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                    .overlay(
                        Text("\(index)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white)
                    )
            }
            if point.isOutOfBounds {
                Image(systemName: "nosign")
                    .foregroundStyle(Color.pink)
                    .font(.system(size: 25, weight: .bold))
            }
        }
    }
}

struct RadiusRoutePointView: View {
    @ObservedObject var store: RouteEditorStore
    let point: EditableRoutePoint
    let metersPerPoint: Double
    let isSelected: Bool

    var body: some View {
        ZStack {
            let isOverlapping = store.isPointOverlapping(id: point.id)
            Circle()
                .stroke(isOverlapping ? Color.red : Color.green.opacity(0.5), lineWidth: 2)
                .frame(
                    width: 2.0 * radiusToPixels(point.radius),
                    height: 2.0 * radiusToPixels(point.radius)
                )
            RoutePointView(point: point)
                .scaleEffect(isSelected ? 1.4 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isSelected)
            if let penalty = point.penalty {
                Text("+\(penalty)s")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(penalty > 0 ? Color.pink.opacity(0.8) : Color.green.opacity(0.8))
                    )
                    .offset(y: 18)
            }
        }
    }

    func radiusToPixels(_ meters: Double) -> CGFloat {
        guard metersPerPoint > 0 else { return 0 }
        return CGFloat(meters / metersPerPoint)
    }
}

struct EditableRoutePointView: View {
    let point: EditableRoutePoint
    let isSelected: Bool
    var onTap: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoutePointView(point: point)
                .frame(width: 50, height: 50)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 3)
                )
                .shadow(radius: 2)
                .onTapGesture {
                    onTap()
                }
            if case .checkPoint = point.type {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .background(Color.white.clipShape(Circle()))
                }
                .offset(x: 6, y: -6)
            }
        }
    }
}

struct RouteOverlayView: View {
    @ObservedObject var camera: MapCameraState
    @ObservedObject var store: RouteEditorStore
    //@Binding var points: [EditableRoutePoint]
    @Binding var selectedPointID: UUID?

    var body: some View {
        ZStack {
            // 路径线
            Path { path in
                guard let first = store.tempRoutePoints.first else { return }
                
                let start = camera.project(first.coordinate)
                path.move(to: start)
                
                for p in store.tempRoutePoints.dropFirst() {
                    path.addLine(to: camera.project(p.coordinate))
                }
            }
            .stroke(.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [6, 8]))
            
            // points + radius
            ForEach(store.tempRoutePoints) { point in
                let screenPos = camera.project(point.coordinate)
                RadiusRoutePointView(
                    store: store,
                    point: point,
                    metersPerPoint: camera.metersPerPoint,
                    isSelected: point.id == selectedPointID
                )
                .position(screenPos)
                .transaction { $0.animation = nil }
            }
        }
    }

    func color(for point: EditableRoutePoint) -> Color {
        switch point.type {
        case .start: return .green
        case .end: return .red
        case .checkPoint: return .orange
        }
    }
}

/*#Preview {
    let appState = AppState.shared
    return SportCenterView()
        .environmentObject(appState)
        .preferredColorScheme(.dark)
}*/
