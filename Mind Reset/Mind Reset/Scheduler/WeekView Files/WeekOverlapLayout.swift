//
//  WeekOverlapLayout.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 7/9/25.
//

import SwiftUI

/// Groups overlapping blocks **within a single day** so they can be laid out in columns.
struct WeekOverlapLayout {

    /// One column-group of overlapping blocks
    struct Group: Identifiable {
        let id = UUID()
        var blocks: [TimelineBlock]
    }

    /// Greedy O(*n²*) sweep that stuffs each block into the first
    /// group it overlaps with, or starts a new group if none.
    static func compute(_ items: [TimelineBlock]) -> [Group] {
        var groups: [Group] = []
        for blk in items.sorted(by: { $0.start < $1.start }) {

            if let i = groups.firstIndex(where: { g in
                g.blocks.contains { $0.start < blk.end && blk.start < $0.end }
            }) {
                groups[i].blocks.append(blk)          // add to existing overlap column
            } else {
                groups.append(Group(blocks: [blk]))   // start a new column
            }
        }
        return groups
    }
}

