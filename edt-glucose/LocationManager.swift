//
//  LocationManager.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import CoreLocation

@MainActor @Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var currentPlaceName: String?
    var isLocating = false
    var locationError: String?

    private var continuation: CheckedContinuation<String?, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocationName() async -> String? {
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
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            let name = placemarks?.first.map { placemark in
                [placemark.name, placemark.locality]
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }
            Task { @MainActor in
                self.currentPlaceName = name
                self.finishWithResult(name)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error.localizedDescription
            self.finishWithResult(nil)
        }
    }

    private func finishWithResult(_ result: String?) {
        isLocating = false
        continuation?.resume(returning: result)
        continuation = nil
    }
}
