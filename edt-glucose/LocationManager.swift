//
//  LocationManager.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/28/26.
//

import CoreLocation
import MapKit

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
            Task { @MainActor in self.finishWithResult(nil) }
            return
        }
        Task { @MainActor in
            await self.processLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error.localizedDescription
            self.finishWithResult(nil)
        }
    }

    @MainActor
    private func processLocation(_ location: CLLocation) async {
        let coords = String(format: "%.6f,%.6f",
                            location.coordinate.latitude,
                            location.coordinate.longitude)
        let mapItem = await reverseGeocode(location)

        let name: String? = {
            guard let mapItem else { return nil }
            // Prefer the descriptive name (POI) plus locality (city) — matches the
            // old "name, locality" format.
            let locality = mapItem.addressRepresentations?.cityWithContext(.short)
            return [mapItem.name, locality]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }()

        let address: String? = mapItem?.address?.fullAddress

        let details = LocationDetails(
            displayName: (name?.isEmpty ?? true) ? nil : name,
            streetAddress: (address?.isEmpty ?? true) ? nil : address,
            gpsCoordinates: coords
        )
        currentPlaceName = details.displayName
        finishWithResult(details)
    }

    private func reverseGeocode(_ location: CLLocation) async -> MKMapItem? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        do {
            let items = try await request.mapItems
            return items.first
        } catch {
            return nil
        }
    }

    private func finishWithResult(_ result: LocationDetails?) {
        isLocating = false
        continuation?.resume(returning: result)
        continuation = nil
    }
}
