import Foundation

/// Version + build info shown under the main "Blood Glucose" title.
/// `BuildInfo.plist` is generated into the app bundle by the "Build Info"
/// Run Script phase (`scripts/build-info.sh`); the build number increments on
/// every device build and every commit (see `build-number.txt`).
enum BuildInfo {
    static let marketingVersion: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    private static let generated: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "BuildInfo", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }()

    static let buildNumber: Int? = generated["BuildNumber"] as? Int
    static let buildDate: Date? = generated["BuildDate"] as? Date

    /// e.g. "Version 1.5 (7) · Oct 10, 2026"
    static var displayString: String {
        var text = "Version \(marketingVersion)"
        if let buildNumber {
            text += " (\(buildNumber))"
        }
        if let buildDate {
            text += " · " + buildDate.formatted(date: .abbreviated, time: .omitted)
        }
        return text
    }
}
