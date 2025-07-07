//
//  MetricTypePicker.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 1/29/25.
//

import SwiftUI

struct MetricTypePicker: View {
    let category: MetricCategory
    @Binding var selectedMetricType: MetricType
    @Binding var customMetricTypeInput: String
    
    // Local styling constants matching Metric Category style
    private let textFieldBackground = Color(red: 0.15, green: 0.15, blue: 0.15)
    private let accentColor = Color(red: 0, green: 1, blue: 1) // Electric blue/cyan
    private let textColor = Color.white.opacity(0.8)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header text placed above the dropdown (grey box)
            Text("Metric Type")
                .foregroundColor(accentColor)
                .fontWeight(.semibold)
            
            // The dropdown menu styled as a grey box with a down arrow
            Menu {
                // List all predefined metric types for this category
                ForEach(category.metricTypes, id: \.self) { metric in
                    Button(action: {
                        selectedMetricType = metric
                    }) {
                        Text(metric.displayName)
                            .foregroundColor(textColor)
                    }
                }
                // Append the "Custom" option explicitly
                Button(action: {
                    selectedMetricType = .custom("")
                }) {
                    Text("Custom")
                        .foregroundColor(textColor)
                }
            } label: {
                HStack {
                    Text(selectedMetricType.displayName)
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(textColor)
                }
                .padding(.vertical)
                .padding(.horizontal)
                .background(textFieldBackground)
                .cornerRadius(8)
            }
            .accessibilityLabel("Metric Type Picker")
            .accessibilityHint("Select a metric type for your habit")
            
            // Display a TextField for custom input when the custom option is selected
            if case .custom("") = selectedMetricType {
                TextField("", text: $customMetricTypeInput, prompt: Text("Enter your own metric type")
                            .foregroundColor(Color.white.opacity(0.9)))
                    .foregroundColor(textColor)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(textFieldBackground)
                    .cornerRadius(8)
                    .accessibilityLabel("Custom Metric Type")
                    .accessibilityHint("Enter your own metric type")
            }
        }
    }
}

// MARK: - MetricType Extension
extension MetricType {
    /// Returns a display-friendly name for the metric.
    var displayName: String {
        switch self {
        case .predefined(let type):
            return type
        case .custom(let type):
            return type.isEmpty ? "Custom" : type
        }
    }
}

// MARK: - Preview
struct MetricTypePicker_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUI.Group {
            // Preview for a predefined category (e.g. Time Metrics)
            MetricTypePicker(
                category: .time,
                selectedMetricType: .constant(.predefined("Minutes")),
                customMetricTypeInput: .constant("")
            )
            .previewDisplayName("Time Metrics")
            .padding()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
            
            // Preview for the custom option (Custom Metrics)
            MetricTypePicker(
                category: .custom,
                selectedMetricType: .constant(.custom("Custom Metric")),
                customMetricTypeInput: .constant("Custom Metric")
            )
            .previewDisplayName("Custom Metrics")
            .padding()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
        }
    }
}
