//
//  MacroRingView.swift
//  MacroBara
//

import SwiftUI

struct MacroRingView: View {
    var title: String
    var current: Double
    var target: Double
    var unit: String
    var color: Color
    var lineWidth: CGFloat = 8
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, max(0.0, current / target))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: lineWidth)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                
                VStack(spacing: 2) {
                    Text("\(Int(current))")
                        .font(.system(.title3, design: .rounded).bold())
                    Text("/\(Int(target))\(unit)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
