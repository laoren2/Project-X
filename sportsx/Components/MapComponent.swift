//
//  MapComponent.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/22.
//

import MapKit
import SwiftUI


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
        context.setLineWidth(4 / zoomScale)
        context.setLineCap(.round)
        
        for i in 0..<(polyline.speeds.count - 1) {
            let p1 = point(for: points[i])
            let p2 = point(for: points[i+1])
            
            let color1 = colorForSpeed(polyline.speeds[i])
            let color2 = colorForSpeed(polyline.speeds[i+1])
            
            // 渐变
            let colors = [color1.cgColor, color2.cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors,
                                         locations: locations) {
                context.saveGState()
                let path = CGMutablePath()
                path.move(to: p1)
                path.addLine(to: p2)
                context.addPath(path)
                context.replacePathWithStrokedPath()
                context.clip()
                
                context.drawLinearGradient(gradient,
                                           start: p1,
                                           end: p2,
                                           options: [])
                context.restoreGState()
            }
        }
    }
    
    private func colorForSpeed(_ speed: Double) -> UIColor {
        // 连续渐变：蓝(慢) → 绿 → 黄 → 红(快)
        let ratio = min(max(speed / 40.0, 0), 1) // 假设 0~40 km/h
        return UIColor(hue: (0.6 - 0.6 * ratio), saturation: 1, brightness: 1, alpha: 1)
        // hue=0.6 蓝色, hue=0  红色
    }
}

// MARK: - 在地图上显示渐变路径
struct GradientPathMapView: UIViewRepresentable {
    let path: [PathPoint]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        if !path.isEmpty {
            // 大陆境内转需要换坐标系
            var coords = path.map { CoordinateConverter.wgs84ToGcj02(lat: $0.lat, lon: $0.lon) }
            let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
            polyline.speeds = path.map { $0.speed }
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
        }
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? SpeedPolyline {
                return SpeedPolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer()
        }
    }
}
