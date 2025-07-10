//
//  HorizontalGridLinesView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 7/9/25.
//


import SwiftUI

/// Draws N equally‐spaced horizontal lines at `rowHeight` intervals.
struct HorizontalGridLinesView: View {
    let rowCount: Int
    let rowHeight: CGFloat
    let lineColor: Color = Color(.systemGray3)

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: rowHeight)
                    .overlay(
                        Rectangle()
                            .fill(lineColor)
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
            }
        }
    }
}
