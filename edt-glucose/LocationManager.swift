//
//  LocationManager.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import CoreLocation

struct LocationDetails {
    /// Short display name: "<place name>, <locality>" — same as the legacy `requestLocationName` result.
    var displayName: String?
    /// Full street address (number, street, locality, region, postal code, country).
    var streetAddress: String?
    /// "lat,lon" with 6-decimal precision.
    var gpsCoordinates: String?
}

@MainActor @Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var currentPlaceName: String?
    var isLocating = false
    var locationError: String?

    private var continuation: CheckedContinuation<LocationDetails?, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Legacy helper — returns only the display name.
    func requestLocationName() async -> String? {
        await requestLocationDetails()?.displayName
    }

    func requestLocationDetails() async -> LocationDetails? {
        isLocating = true
        locationError = nil
        currentPlaceName = nil

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Wait briefly for authorization response
            try? await Task.sleep(for: .seconds(1))
        }

        guard manager.authorizationStatus == .authorizedWhenInUse
           || manager.authorizationStatus == .authorizedAlways else {
            isLocating = false
            locationError = "Location access denied"
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            Task { @MainActor in
                self.finishWithResult(nil)
            }
            return
        }
        let coords = String(format: "%.6f,%.6f",
                            location.coordinate.latitude,
                            location.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            let placemark = placemarks?.first
            let name = placemark.map { p in
                [p.name, p.locality]
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }
            let address = placemark.map { p -> String in
                let line1 = [p.subThoroughfare, p.thoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let line2 = [p.locality, p.administrativeArea, p.postalCode]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                return [line1, line2, p.country]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            }
            let details = LocationDetails(
                displayName: name,
                streetAddress: address?.isEmpty == false ? address : nil,
                gpsCoordinates: coords
            )
            Task { @MainActor in
                self.currentPlaceName = name
                self.finishWithResult(details)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error.localizedDescription
            self.finishWithResult(nil)
        }
    }

    private func finishWithResult(_ result: LocationDetails?) {
        isLocating = false
        continuation?.resume(returning: result)
        continuation = nil
    }
}
