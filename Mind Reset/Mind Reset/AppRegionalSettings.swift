//
//  AppRegionalSettings.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 6/25/25.
//


//  AppRegionalSettings.swift
//  Mind Reset

import SwiftUI
import Combine

extension Notification.Name {
    /// Posted right after the user saves a new “Date format” in Regional Settings.
    static let dateFormatChanged = Notification.Name("dateFormatChanged")
}
/// A tiny ObservableObject that exposes the user’s “Week begins on” index
/// **and** the preferred date-format pattern (`"MM/dd/yyyy"` … `"MMMM d, yyyy"`).
///
/// • The object watches UserDefaults and republishes whenever either value
///   changes.
///
/// • One instance is created in `MindResetApp` (or whatever your @main file
///   is called) and injected with `.environmentObject(_)`.
final class AppRegionalSettings: ObservableObject {

    // MARK: Published values other views can observe
    @Published private(set) var weekStartIndex: Int
    @Published private(set) var dateFormatPattern: String

    // Expose a ready-to-use DateFormatter so views don’t create new ones
    private let formatter = DateFormatter()
    var dateFormatter: DateFormatter { formatter }

    // MARK: Init
    init() {
        let ud = UserDefaults.standard
        weekStartIndex    = ud.integer(forKey: "weekStartIndex")
        dateFormatPattern = ud.string(forKey: "dateFormatStyle") ?? "MM/dd/yyyy"
        formatter.dateFormat = dateFormatPattern

        // Observe both keys
        NotificationCenter.default.addObserver(
            forName: .weekStartChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
        NotificationCenter.default.addObserver(
            forName: .dateFormatChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    private func reload() {
        let ud = UserDefaults.standard
        weekStartIndex    = ud.integer(forKey: "weekStartIndex")
        let newPattern    = ud.string(forKey: "dateFormatStyle") ?? "MM/dd/yyyy"
        if newPattern != dateFormatPattern {
            dateFormatPattern = newPattern
            formatter.dateFormat = newPattern
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

// Convenience so any `Date` can be formatted in one call.
extension Date {
    func pretty(using settings: AppRegionalSettings) -> String {
        settings.dateFormatter.string(from: self)
    }
}
