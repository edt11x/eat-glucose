//
//  NotificationManager.swift
//  edt-glucose
//
//  Created by Edward Thompson on 3/7/26.
//

import Foundation
import UserNotifications

actor NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func scheduleRandomPostMealTimer() async {
        let settings = SettingsManager.shared
        let values = settings.postMealTimerValues.filter { $0 > 0 }
        guard !values.isEmpty else { return }

        guard let minutes = values.randomElement() else { return }
        let seconds = TimeInterval(minutes * 60)

        let hasPermission = await requestPermission()
        guard hasPermission else { return }

        let content = UNMutableNotificationContent()
        content.title = "Blood Glucose Check"
        content.body = "It's been \(minutes) minutes since your meal ended. Time to check your blood glucose!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "postMealTimer-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Notification scheduling failed silently
        }
    }
}
