import SwiftUI
import UIKit
import MapKit

/// خريطة MKMapView داكنة: خلايا سداسيّة ملوّنة حسب الطزاجة + مسار متوهّج
struct MasarMap: UIViewRepresentable {
    var routes: [[CLLocationCoordinate2D]]
    var hexes: [MapHex]
    var hexKey: Int
    var routeKey: Int
    var fitKey: Int
    var follow: Bool = false
    var showsUser: Bool = false
    var interactive: Bool = true
    var bottomPad: CGFloat = 40
    var fitToRoute: Bool = false
    var fallback: CLLocationCoordinate2D = Demo.center.cl

    func makeCoordinator() -> MasarMapCoordinator { MasarMapCoordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let m = MKMapView(frame: .zero)
        m.delegate = context.coordinator
        m.overrideUserInterfaceStyle = .dark
        m.pointOfInterestFilter = .excludingAll
        m.showsCompass = false
        m.showsScale = false
        m.isPitchEnabled = false
        m.isRotateEnabled = false
        m.isScrollEnabled = interactive
        m.isZoomEnabled = interactive
        m.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        m.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        m.setRegion(MKCoordinateRegion(center: fallback, latitudinalMeters: 2500, longitudinalMeters: 2500), animated: false)
        return m
    }

    func updateUIView(_ m: MKMapView, context: Context) {
        let c = context.coordinator
        if m.showsUserLocation != showsUser { m.showsUserLocation = showsUser }

        if c.hexKey != hexKey {
            c.hexKey = hexKey
            m.removeOverlays(c.hexOverlays)
            c.hexOverlays = MasarMap.hexOverlays(hexes)
            m.addOverlays(c.hexOverlays, level: .aboveRoads)
        }

        if c.routeKey != routeKey {
            c.routeKey = routeKey
            m.removeOverlays(c.routeOverlays)
            let lines: [MKPolyline] = routes.filter { $0.count > 1 }.map { MKPolyline(coordinates: $0, count: $0.count) }
            var ov: [MKOverlay] = []
            if !lines.isEmpty {
                let glow = MKMultiPolyline(lines)
                glow.title = "glow"
                let core = MKMultiPolyline(lines)
                core.title = "core"
                ov = [glow, core]
            }
            c.routeOverlays = ov
            m.addOverlays(ov, level: .aboveLabels)
        }

        if follow && showsUser {
            if m.userTrackingMode != .follow { m.setUserTrackingMode(.follow, animated: true) }
        } else if m.userTrackingMode != .none {
            m.setUserTrackingMode(.none, animated: false)
        }

        if c.fitKey != fitKey && !follow {
            c.fitKey = fitKey
            let routePts: [CLLocationCoordinate2D] = routes.flatMap { $0 }
            let pts: [CLLocationCoordinate2D] = (fitToRoute && routePts.count > 1) ? routePts : routePts + hexes.flatMap { $0.corners }
            c.fit(m, pts, bottom: bottomPad)
        }
    }

    static func hexOverlays(_ hexes: [MapHex]) -> [MKOverlay] {
        var groups: [Int: [MKPolygon]] = [:]
        for h in hexes where h.corners.count >= 3 {
            groups[h.tone, default: []].append(MKPolygon(coordinates: h.corners, count: h.corners.count))
        }
        var out: [MKOverlay] = []
        for tone in [4, 3, 2, 1, 0] {
            guard let g = groups[tone], !g.isEmpty else { continue }
            let mp = MKMultiPolygon(g)
            mp.title = "t\(tone)"
            out.append(mp)
        }
        return out
    }
}

final class MasarMapCoordinator: NSObject, MKMapViewDelegate {
    var hexKey = Int.min
    var routeKey = Int.min
    var fitKey = Int.min
    var hexOverlays: [MKOverlay] = []
    var routeOverlays: [MKOverlay] = []

    static func color(_ tone: Int) -> UIColor {
        switch tone {
        case 0: return UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1)
        case 1: return UIColor(red: 0.22, green: 0.98, blue: 0.72, alpha: 1)
        case 2: return UIColor(red: 0.25, green: 0.80, blue: 1.0, alpha: 1)
        case 3: return UIColor(red: 0.50, green: 0.48, blue: 1.0, alpha: 1)
        default: return UIColor(red: 0.62, green: 0.40, blue: 0.95, alpha: 1)
        }
    }

    static func fillAlpha(_ tone: Int) -> CGFloat {
        switch tone {
        case 0: return 0.42
        case 1: return 0.34
        case 2: return 0.26
        case 3: return 0.18
        default: return 0.10
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let mp = overlay as? MKMultiPolygon {
            let r = MKMultiPolygonRenderer(multiPolygon: mp)
            let tone = Int((mp.title ?? "t1").dropFirst()) ?? 1
            let c = MasarMapCoordinator.color(tone)
            r.fillColor = c.withAlphaComponent(MasarMapCoordinator.fillAlpha(tone))
            r.strokeColor = c.withAlphaComponent(min(1, MasarMapCoordinator.fillAlpha(tone) * 2.2))
            r.lineWidth = tone == 0 ? 1.4 : 0.8
            return r
        }
        if let ml = overlay as? MKMultiPolyline {
            let r = MKMultiPolylineRenderer(multiPolyline: ml)
            r.lineCap = .round
            r.lineJoin = .round
            if ml.title == "glow" {
                r.strokeColor = UIColor(red: 1.0, green: 0.45, blue: 0.30, alpha: 0.28)
                r.lineWidth = 12
            } else {
                r.strokeColor = UIColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 1)
                r.lineWidth = 4
            }
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func fit(_ m: MKMapView, _ pts: [CLLocationCoordinate2D], bottom: CGFloat, tries: Int = 0) {
        guard !pts.isEmpty else { return }
        var rect = MKMapRect.null
        for p in pts {
            let mp = MKMapPoint(p)
            rect = rect.union(MKMapRect(x: mp.x, y: mp.y, width: 1, height: 1))
        }
        let minSide = 600.0 * MKMapPointsPerMeterAtLatitude(pts[0].latitude)
        if rect.size.width < minSide {
            rect = rect.insetBy(dx: -(minSide - rect.size.width) / 2, dy: 0)
        }
        if rect.size.height < minSide {
            rect = rect.insetBy(dx: 0, dy: -(minSide - rect.size.height) / 2)
        }
        let finalRect = rect
        DispatchQueue.main.asyncAfter(deadline: .now() + (tries == 0 ? 0.05 : 0.3)) { [weak self, weak m] in
            guard let m = m else { return }
            if m.bounds.width < 10 && tries < 4 { self?.fit(m, pts, bottom: bottom, tries: tries + 1); return }
            m.setVisibleMapRect(finalRect, edgePadding: UIEdgeInsets(top: 90, left: 30, bottom: bottom, right: 30), animated: false)
        }
    }
}
