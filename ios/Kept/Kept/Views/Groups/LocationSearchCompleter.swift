import Foundation
import MapKit
import CoreLocation

/// Backs the location field on Create Group: typing filters a live dropdown of real places
/// via MapKit's on-device search completer (no external API key needed), and each result
/// resolves to an actual coordinate when picked.
@MainActor
final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
    }

    func search(_ query: String) {
        completer.queryFragment = query
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> (label: String, latitude: Double, longitude: Double)? {
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        guard let response = try? await search.start(), let item = response.mapItems.first else { return nil }
        let label = completion.subtitle.isEmpty ? completion.title : "\(completion.title), \(completion.subtitle)"
        return (label, item.placemark.coordinate.latitude, item.placemark.coordinate.longitude)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in self.results = completer.results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}

/// One-shot "use my current location" lookup, resolved to a city/area label via reverse
/// geocoding — wrapped in a delegate + continuation since CLLocationManager predates
/// async/await.
@MainActor
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func currentPlace() async -> (label: String, latitude: Double, longitude: Double)? {
        guard let location = await currentLocation() else { return nil }
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        let placemark = placemarks?.first
        let label = [placemark?.locality, placemark?.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
        return (
            label.isEmpty ? "Current location" : label,
            location.coordinate.latitude,
            location.coordinate.longitude
        )
    }

    private func currentLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                self.continuation = nil
                continuation.resume(returning: nil)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.continuation?.resume(returning: nil)
                self.continuation = nil
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.continuation?.resume(returning: locations.first)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(returning: nil)
            self.continuation = nil
        }
    }
}
