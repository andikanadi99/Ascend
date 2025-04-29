//
//  NotificationDelegate.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/27/25.
//


import UserNotifications

/// A singleton delegate that lets us present notifications when the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // When a notification arrives while the app is running, show banner & play sound
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                   @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.banner, .sound])
    }
}
