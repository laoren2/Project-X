//
//  MapComponent.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/22.
//

import MapKit
import SwiftUI


enum MapViewMode {
    case overview      // 显示起点与终点
    case followUser    // 跟随用户位置
    case manual        // 用户拖动后的自由模式
}

// MARK: - Polyline with speeds
class SpeedPolyline: MKPolyline {
    var speeds: [Double] = []
}

// MARK: - Renderer
class SpeedPolylineRenderer: MKOverlayRenderer {
    let polyline: SpeedPolyline
    
    init(polyline: SpeedPolyline) {
        self.polyline = polyline
        super.init(overlay: polyline)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount > 1 else { return }
        
        let points = polyline.points()
        
        for i in 0..<(polyline.speeds.count - 1) {
            let p1 = point(for: points[i])
            let p2 = point(for: points[i + 1])
            
            let color1 = colorForSpeed(polyline.speeds[i])
            let color2 = colorForSpeed(polyline.speeds[i + 1])
            let colors = [color1.cgColor, color2.cgColor] as CFArray
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors,
                                         locations: [0.0, 1.0]) {
                context.saveGState()
                
                let path = CGMutablePath()
                path.move(to: p1)
                path.addLine(to: p2)
                
                context.addPath(path)
                context.setLineWidth(5 / zoomScale)
                context.setLineJoin(.round)
                context.setLineCap(.round)
                
                // 关键：每段独立clip
                context.replacePathWithStrokedPath()
                context.clip()
                
                context.drawLinearGradient(
                    gradient,
                    start: p1,
                    end: p2,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
                
                context.restoreGState()
            }
        }
    }
    
    private func colorForSpeed(_ speed: Double) -> UIColor {
        // 蓝(慢) → 绿 → 黄 → 红(快)
        let ratio = min(max(speed / 30.0, 0), 1)
        return UIColor(hue: (0.6 - 0.6 * ratio), saturation: 1, brightness: 1, alpha: 1)
    }
}

// MARK: - 进行时的路径 Map 视图
struct RealtimeMapView: UIViewRepresentable {
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    let startRadius: CLLocationDistance
    let endRadius: CLLocationDistance
    let path: [PathPoint]
    let isReverse: Bool
    @Binding var mapMode: MapViewMode       // 新增
    @Binding var userLocation: CLLocation?  // 用于跟随模式

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        
        let parseFromCoordinate = CoordinateConverter.parseCoordinate(coordinate: fromCoordinate)
        let parseToCoordinate = CoordinateConverter.parseCoordinate(coordinate: toCoordinate)
        context.coordinator.fromAnnotation.coordinate = parseFromCoordinate
        context.coordinator.toAnnotation.coordinate = parseToCoordinate
        mapView.addAnnotations([context.coordinator.fromAnnotation, context.coordinator.toAnnotation])
        let circle1 = MKCircle(center: parseFromCoordinate, radius: startRadius)
        let circle2 = MKCircle(center: parseToCoordinate, radius: endRadius)
        mapView.addOverlays([circle1, circle2])
        
        context.coordinator.lastPointCount = 0
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let from = isReverse ? CoordinateConverter.reverseParseCoordinate(coordinate: fromCoordinate) : CoordinateConverter.parseCoordinate(coordinate: fromCoordinate)
        let to = isReverse ? CoordinateConverter.reverseParseCoordinate(coordinate: toCoordinate) : CoordinateConverter.parseCoordinate(coordinate: toCoordinate)
        if context.coordinator.lastIsReverse != isReverse {
            context.coordinator.fromAnnotation.coordinate = from
            context.coordinator.toAnnotation.coordinate = to
            // 添加圆形覆盖层
            mapView.removeOverlays(mapView.overlays)
            let circle1 = MKCircle(center: from, radius: startRadius)
            let circle2 = MKCircle(center: to, radius: endRadius)
            mapView.addOverlays([circle1, circle2])
            context.coordinator.lastPointCount = 0
            context.coordinator.lastIsReverse = isReverse
        }
        
        switch mapMode {
        case .overview:
            guard context.coordinator.lastMode != .overview else { break }
            //print("switch to overview")
            var rect = MKMapRect.null
            let points = [MKMapPoint(from), MKMapPoint(to)]
            for p in points { rect = rect.union(MKMapRect(origin: p, size: .init(width: 0, height: 0))) }
            context.coordinator.isProgrammaticChange = true
            mapView.setVisibleMapRect(rect, edgePadding: .init(top: 100, left: 80, bottom: 100, right: 80), animated: true)
            DispatchQueue.main.async {
                context.coordinator.isProgrammaticChange = false
            }
        case .followUser:
            //print("switch to followuser")
            if let userLocation = userLocation {
                let location = isReverse ? CoordinateConverter.reverseParseCoordinate(coordinate: userLocation.coordinate) : CoordinateConverter.parseCoordinate(coordinate: userLocation.coordinate)
                let region = MKCoordinateRegion(center: location,
                                                latitudinalMeters: 3 * startRadius,
                                                longitudinalMeters: 3 * startRadius)
                    .centerOffset(byLatitudeMeters: -startRadius / 2)
                context.coordinator.isProgrammaticChange = true
                mapView.setRegion(region, animated: context.coordinator.lastMode != .followUser ? true : false)
                DispatchQueue.main.async {
                    context.coordinator.isProgrammaticChange = false
                }
            }
        case .manual:
            // 不自动更新region
            //print("switch to manual")
            break
        }
        if context.coordinator.lastMode != mapMode {
            context.coordinator.lastMode = mapMode
        }
        
        guard path.count > 1 else { return }
        // 检查是否有新点添加
        let lastCount = context.coordinator.lastPointCount
        if path.count > lastCount + 1 {
            // 多个新点：批量更新
            let newPoints = Array(path[lastCount...])
            addPolylineSegment(to: mapView, from: newPoints)
        } else if path.count == lastCount + 1 {
            // 单个新点：增量更新
            let segment = Array(path.suffix(2))
            addPolylineSegment(to: mapView, from: segment)
        } else if path.count < lastCount {
            // 如果路径被重置，清除所有overlay
            mapView.removeOverlays(mapView.overlays)
            if let firstPolyline = makePolyline(from: path) {
                mapView.addOverlay(firstPolyline)
                mapView.setVisibleMapRect(firstPolyline.boundingMapRect, edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40), animated: false)
            }
        }
        context.coordinator.lastPointCount = path.count
    }
    
    private func addPolylineSegment(to mapView: MKMapView, from segment: [PathPoint]) {
        guard segment.count >= 2 else { return }
        
        var coords = segment.map {
            isReverse ? CoordinateConverter.reverseParseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) : CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon))
        }
        let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
        polyline.speeds = segment.map { $0.speed }
        mapView.addOverlay(polyline)
    }
    
    private func makePolyline(from path: [PathPoint]) -> SpeedPolyline? {
        guard !path.isEmpty else { return nil }
        var coords = path.map {
            isReverse ? CoordinateConverter.reverseParseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) : CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon))
        }
        let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
        polyline.speeds = path.map { $0.speed }
        return polyline
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RealtimeMapView
        let fromAnnotation = MKPointAnnotation()
        let toAnnotation = MKPointAnnotation()
        // 缓存
        var lastPointCount: Int = 0
        var lastIsReverse: Bool = false
        var lastMode: MapViewMode = .followUser
        // 识别 Map 视角变化的来源
        var isProgrammaticChange = true
        
        init(_ parent: RealtimeMapView) {
            self.parent = parent
            self.fromAnnotation.title = "From"
            self.toAnnotation.title = "To"
        }
        
        func setRegionProgrammatically(_ mapView: MKMapView, region: MKCoordinateRegion, animated: Bool) {
            isProgrammaticChange = true
            mapView.setRegion(region, animated: animated)
            DispatchQueue.main.async {
                self.isProgrammaticChange = false
            }
        }
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            //print("regionWillChangeAnimated: \(isProgrammaticChange)")
            if !isProgrammaticChange {
                DispatchQueue.main.async {
                    self.parent.mapMode = .manual
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.orange.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.orange.withAlphaComponent(0.6)
                renderer.lineWidth = 2
                return renderer
            }
            if let polyline = overlay as? SpeedPolyline {
                return SpeedPolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - 比赛数据结算的 Map 视图
struct GradientPathMapView: UIViewRepresentable {
    let path: [PathPoint]
    let highlightedIndex: Int
    
    private let highlightAnnotationId = "highlightAnnotation"
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        if !path.isEmpty {
            var coords = path.map { CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
            let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
            polyline.speeds = path.map { $0.speed }
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
        }
        
        // 添加起点 annotation（绿色圆点）
        if let first = path.first {
            let parseFirst = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon))
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = CLLocationCoordinate2D(latitude: parseFirst.latitude, longitude: parseFirst.longitude)
            startAnnotation.title = "startAnnotation"
            mapView.addAnnotation(startAnnotation)
        }
        // 添加终点 annotation（红色圆点）
        if let last = path.last {
            let parseLast = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon))
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = CLLocationCoordinate2D(latitude: parseLast.latitude, longitude: parseLast.longitude)
            endAnnotation.title = "endAnnotation"
            mapView.addAnnotation(endAnnotation)
        }
        
        // 隐藏底部 "Legal" 图标
        for subview in mapView.subviews {
            if String(describing: type(of: subview)).contains("Attribution") {
                subview.isHidden = true
            }
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard !path.isEmpty, highlightedIndex < path.count else { return }
        
        // 移除旧的高亮 annotation
        let existing = mapView.annotations.filter { $0.title == highlightAnnotationId }
        mapView.removeAnnotations(existing)
        
        // 添加新的高亮 annotation
        let coord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: path[highlightedIndex].lat, longitude: path[highlightedIndex].lon))
        let annotation = MKPointAnnotation()
        annotation.coordinate = coord
        annotation.title = highlightAnnotationId
        mapView.addAnnotation(annotation)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? SpeedPolyline {
                return SpeedPolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let title = annotation.title ?? nil else { return nil }
            if title == "highlightAnnotation" {
                let id = "highlightView"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    view?.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                    view?.layer.cornerRadius = 7
                    view?.layer.borderColor = UIColor.white.cgColor
                    view?.layer.borderWidth = 2
                    view?.backgroundColor = UIColor.systemBlue
                    view?.canShowCallout = false
                } else {
                    view?.annotation = annotation
                }
                return view
            } else if title == "startAnnotation" {
                let id = "startView"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    view?.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                    view?.layer.cornerRadius = 7
                    view?.layer.borderColor = UIColor.white.cgColor
                    view?.layer.borderWidth = 2
                    view?.backgroundColor = UIColor.systemGreen
                    view?.canShowCallout = false
                } else {
                    view?.annotation = annotation
                }
                return view
            } else if title == "endAnnotation" {
                let id = "endView"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    view?.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                    view?.layer.cornerRadius = 7
                    view?.layer.borderColor = UIColor.white.cgColor
                    view?.layer.borderWidth = 2
                    view?.backgroundColor = UIColor.systemRed
                    view?.canShowCallout = false
                } else {
                    view?.annotation = annotation
                }
                return view
            }
            return nil
        }
    }
}
