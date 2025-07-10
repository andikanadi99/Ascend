//
//  WeekHeaderView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 7/10/25.
//
import SwiftUI

struct WeekHeaderView: View {
  let weekStart: Date
  private var days: [Date] {
    (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: weekStart)! }
  }

  var body: some View {
    HStack(spacing:0) {
      Text("") .frame(width: 50) // spacer under the hour‐labels column
      ForEach(days, id:\.self) { day in
        VStack {
          Text(day, format: .dateTime.weekday(.abbreviated))
          Text(day, format: .dateTime.day())
        }
        .frame(width: 120) // same width as your columns
      }
    }
    .font(.caption)
    .padding(.vertical, 4)
  }
}
