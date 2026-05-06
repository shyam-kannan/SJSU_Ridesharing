import SwiftUI
import MapKit

struct RouteMapInfo: Equatable {
    let distanceMeters: CLLocationDistance
    let expectedTravelTime: TimeInterval
}

struct RouteMapView: UIViewRepresentable {
    let origin: CLLocationCoordinate2D?
    let destination: CLLocationCoordinate2D?
    let driver: CLLocationCoordinate2D?
    var waypoint: CLLocationCoordinate2D? = nil
    var routeStart: CLLocationCoordinate2D? = nil
    var routeEnd: CLLocationCoordinate2D? = nil
    var riders: [CLLocationCoordinate2D] = []
    var fitAnchors: [CLLocationCoordinate2D]? = nil
    var showsUserLocation: Bool = true
    var onRouteUpdated: ((RouteMapInfo?) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsCompass = false
        map.showsScale = false
        map.pointOfInterestFilter = .excludingAll
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsUserLocation = showsUserLocation
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.mapView = mapView
        context.coordinator.onRouteUpdated = onRouteUpdated
        mapView.showsUserLocation = showsUserLocation

        context.coordinator.syncAnnotations(
            origin: origin,
            destination: destination,
            driver: driver,
            riders: riders
        )

        let routeFrom = routeStart ?? origin
        let routeTo = routeEnd ?? destination
        if let routeFrom, let routeTo {
            if let wp = waypoint {
                context.coordinator.updateRouteWithWaypoint(from: routeFrom, via: wp, to: routeTo)
            } else {
                context.coordinator.updateRoute(from: routeFrom, to: routeTo)
            }
        }

        context.coordinator.fitVisibleRegionIfNeeded(
            mapView,
            coordinates: fitAnchors ?? stableFitCoordinates(
                origin: origin,
                destination: destination,
                driver: driver,
                riders: riders
            )
        )
    }

    private func stableFitCoordinates(
        origin: CLLocationCoordinate2D?,
        destination: CLLocationCoordinate2D?,
        driver: CLLocationCoordinate2D?,
        riders: [CLLocationCoordinate2D]
    ) -> [CLLocationCoordinate2D] {
        if let origin, let destination { return [origin, destination] }
        if let origin { return [origin] }
        if let destination { return [destination] }
        if let driver { return [driver] }
        return riders
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapView: MKMapView?
        var onRouteUpdated: ((RouteMapInfo?) -> Void)?
        private var currentDirections: MKDirections?
        private var lastRouteKey: String?
        private var cachedPolyline: MKPolyline?
        private var cachedRouteInfo: RouteMapInfo?
        private var lastFitKey: String?
        private var lastDirectionsRequestAt: Date?
        private var lastDirectionsOrigin: CLLocationCoordinate2D?
        private var lastDirectionsDestination: CLLocationCoordinate2D?
        private var annotationsByID: [String: MovingPointAnnotation] = [:]

        func syncAnnotations(
            origin: CLLocationCoordinate2D?,
            destination: CLLocationCoordinate2D?,
            driver: CLLocationCoordinate2D?,
            riders: [CLLocationCoordinate2D]
        ) {
            guard let mapView else { return }

            var next: [String: (CLLocationCoordinate2D, String)] = [:]
            if let origin { next["pickup"] = (origin, "pickup") }
            if let destination { next["destination"] = (destination, "destination") }
            if let driver { next["driver"] = (driver, "driver") }
            for (idx, rider) in riders.enumerated() {
                next["rider_\(idx)"] = (rider, "rider")
            }

            let removedKeys = Set(annotationsByID.keys).subtracting(next.keys)
            for key in removedKeys {
                if let annotation = annotationsByID.removeValue(forKey: key) {
                    mapView.removeAnnotation(annotation)
                }
            }

            for (key, payload) in next {
                let (coord, title) = payload
                if let existing = annotationsByID[key] {
                    existing.title = title
                    existing.setCoordinateAnimated(coord)
                } else {
                    let annotation = MovingPointAnnotation(id: key, coordinate: coord, title: title)
                    annotationsByID[key] = annotation
                    mapView.addAnnotation(annotation)
                }
            }
        }

        func updateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
            let key = routeKey(origin: origin, destination: destination)
            let isMinorDriverMove = shouldSkipDirectionsRefresh(origin: origin, destination: destination)

            if (lastRouteKey == key || isMinorDriverMove), let polyline = cachedPolyline {
                if let mapView, !mapView.overlays.contains(where: { ($0 as? MKPolyline) === polyline }) {
                    mapView.addOverlay(polyline)
                }
                onRouteUpdated?(cachedRouteInfo)
                return
            }

            lastRouteKey = key
            cachedPolyline = nil
            cachedRouteInfo = nil
            onRouteUpdated?(nil)

            currentDirections?.cancel()
            lastDirectionsRequestAt = Date()
            lastDirectionsOrigin = origin
            lastDirectionsDestination = destination

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile
            request.requestsAlternateRoutes = false

            let directions = MKDirections(request: request)
            currentDirections = directions

            directions.calculate { [weak self] response, error in
                guard let self else { return }
                guard self.lastRouteKey == key else { return }

                if let route = response?.routes.first {
                    self.cachedPolyline = route.polyline
                    self.cachedRouteInfo = RouteMapInfo(
                        distanceMeters: route.distance,
                        expectedTravelTime: route.expectedTravelTime
                    )
                    DispatchQueue.main.async {
                        guard self.lastRouteKey == key else { return }
                        if let mapView = self.mapView {
                            mapView.removeOverlays(mapView.overlays)
                            mapView.addOverlay(route.polyline)
                        }
                        self.onRouteUpdated?(self.cachedRouteInfo)
                    }
                    return
                }

                // Fallback to a geodesic line if directions fail.
                let fallback = MKGeodesicPolyline(coordinates: [origin, destination], count: 2)
                self.cachedPolyline = fallback
                let straightLineDistance = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                    .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
                self.cachedRouteInfo = RouteMapInfo(
                    distanceMeters: straightLineDistance,
                    expectedTravelTime: (straightLineDistance / 1609.344 / 28.0) * 3600.0
                )
                DispatchQueue.main.async {
                    guard self.lastRouteKey == key else { return }
                    if let mapView = self.mapView {
                        mapView.removeOverlays(mapView.overlays)
                        mapView.addOverlay(fallback)
                    }
                    self.onRouteUpdated?(self.cachedRouteInfo)
                }

                if let error {
                    print("[RouteMapView] Directions error: \(error)")
                }
            }
        }

        func updateRouteWithWaypoint(from origin: CLLocationCoordinate2D, via waypoint: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
            let key = "\(routeKey(origin: origin, destination: waypoint))>\(routeKey(origin: waypoint, destination: destination))"
            guard key != lastRouteKey else { return }
            lastRouteKey = key
            cachedPolyline = nil
            cachedRouteInfo = nil
            onRouteUpdated?(nil)
            currentDirections?.cancel()

            func makeRequest(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> MKDirections {
                let req = MKDirections.Request()
                req.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
                req.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
                req.transportType = .automobile
                req.requestsAlternateRoutes = false
                return MKDirections(request: req)
            }

            let leg1 = makeRequest(from: origin, to: waypoint)
            let leg2 = makeRequest(from: waypoint, to: destination)

            leg1.calculate { [weak self] r1, _ in
                leg2.calculate { [weak self] r2, _ in
                    guard let self, self.lastRouteKey == key else { return }
                    let polyline1 = r1?.routes.first?.polyline ?? MKGeodesicPolyline(coordinates: [origin, waypoint], count: 2)
                    let polyline2 = r2?.routes.first?.polyline ?? MKGeodesicPolyline(coordinates: [waypoint, destination], count: 2)
                    let totalDistance = (r1?.routes.first?.distance ?? 0) + (r2?.routes.first?.distance ?? 0)
                    let totalTime = (r1?.routes.first?.expectedTravelTime ?? 0) + (r2?.routes.first?.expectedTravelTime ?? 0)
                    let info = RouteMapInfo(distanceMeters: totalDistance, expectedTravelTime: totalTime)
                    self.cachedRouteInfo = info
                    DispatchQueue.main.async {
                        guard self.lastRouteKey == key else { return }
                        if let mapView = self.mapView {
                            mapView.removeOverlays(mapView.overlays)
                            mapView.addOverlay(polyline1)
                            mapView.addOverlay(polyline2)
                        }
                        self.onRouteUpdated?(info)
                    }
                }
            }
        }

        private func routeKey(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) -> String {
            "\(origin.latitude.rounded(toPlaces: 5)),\(origin.longitude.rounded(toPlaces: 5))|\(destination.latitude.rounded(toPlaces: 5)),\(destination.longitude.rounded(toPlaces: 5))"
        }

        private func shouldSkipDirectionsRefresh(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) -> Bool {
            guard let lastAt = lastDirectionsRequestAt,
                  let lastOrigin = lastDirectionsOrigin,
                  let lastDestination = lastDirectionsDestination else {
                return false
            }

            let destinationDelta = CLLocation(latitude: lastDestination.latitude, longitude: lastDestination.longitude)
                .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
            let originDelta = CLLocation(latitude: lastOrigin.latitude, longitude: lastOrigin.longitude)
                .distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
            let requestAge = Date().timeIntervalSince(lastAt)

            // Recompute if destination changed materially, otherwise allow small driver moves without rerouting every tick.
            if destinationDelta > 25 { return false }
            if originDelta < 60 && requestAge < 2.5 { return true }
            if requestAge < 1.2 { return true }
            return false
        }

        func fitVisibleRegionIfNeeded(_ mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            guard mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }

            let key = fitKey(for: coordinates)
            guard key != lastFitKey else { return }
            lastFitKey = key

            guard !coordinates.isEmpty else { return }

            if coordinates.count == 1, let only = coordinates.first {
                let region = MKCoordinateRegion(
                    center: only,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                mapView.setRegion(region, animated: true)
                return
            }

            var rect = MKMapRect.null
            for coordinate in coordinates {
                let point = MKMapPoint(coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
                rect = rect.isNull ? pointRect : rect.union(pointRect)
            }

            let minimumRectSide = 8_000.0
            if rect.size.width < minimumRectSide || rect.size.height < minimumRectSide {
                rect = MKMapRect(
                    x: rect.origin.x - max(0, (minimumRectSide - rect.size.width) / 2),
                    y: rect.origin.y - max(0, (minimumRectSide - rect.size.height) / 2),
                    width: max(rect.size.width, minimumRectSide),
                    height: max(rect.size.height, minimumRectSide)
                )
            }

            let edgePadding = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)
            mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: true)
        }

        private func fitKey(for coordinates: [CLLocationCoordinate2D]) -> String {
            coordinates
                .prefix(4)
                .map { "\($0.latitude.rounded(toPlaces: 4)),\($0.longitude.rounded(toPlaces: 4))" }
                .joined(separator: "|")
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.brand)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                renderer.alpha = 0.9
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            let id = "route-annotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.canShowCallout = false
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
            view.glyphTintColor = .white

            let kind = (annotation.title ?? nil) ?? ""
            switch kind {
            case "pickup":
                view.markerTintColor = UIColor(Color.brandGold)
                view.glyphImage = UIImage(systemName: "person.fill")
            case "destination":
                view.markerTintColor = UIColor(Color.brandGreen)
                view.glyphImage = UIImage(systemName: "flag.fill")
            case "driver":
                view.markerTintColor = UIColor(Color.brand)
                view.glyphImage = UIImage(systemName: "car.fill")
            case "rider":
                view.markerTintColor = UIColor(Color.brandRed)
                view.glyphImage = UIImage(systemName: "figure.walk")
            default:
                view.markerTintColor = .systemBlue
                view.glyphImage = UIImage(systemName: "mappin")
            }

            return view
        }
    }
}

private final class MovingPointAnnotation: NSObject, MKAnnotation {
    let id: String
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?

    init(id: String, coordinate: CLLocationCoordinate2D, title: String?) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
    }

    func setCoordinateAnimated(_ newCoordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(newCoordinate) else { return }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.coordinate = newCoordinate
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
